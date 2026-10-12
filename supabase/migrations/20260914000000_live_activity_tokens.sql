-- ============================================================
-- Live Activity (잠금화면 + 다이나믹 아일랜드) 푸시 인프라
--
-- 1) live_activity_tokens : ActivityKit push token 보관
-- 2) live_activity_events : 전송 큐 (DB Webhook이 이 테이블의 INSERT를 감시)
-- 3) 스코어 변경 트리거    : 실제로 점수가 바뀐 경우에만 큐에 넣는다
--
-- 왜 큐 테이블을 두는가:
--   기존 send-push와 동일한 패턴(notifications INSERT → webhook)을 따른다.
--   배치 워커가 bwf_live_matches를 10초마다 upsert하므로 테이블에 직접
--   webhook을 걸면 점수가 그대로여도 매번 호출된다. 트리거로 먼저 걸러
--   APNs 레이트리밋(TooManyProviderTokenUpdates)을 피한다.
-- ============================================================

-- ── 1) 토큰 ────────────────────────────────────────────────
-- ActivityKit 토큰은 device_tokens(FCM)와 성격이 다르다:
--   기기가 아니라 **활동 단위**로 발급되고, 수명 중에도 회전하며,
--   FCM을 거치지 않고 APNs로 직접 쏴야 한다.
create table if not exists public.live_activity_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  match_code text not null,
  push_token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, match_code)
);
comment on table public.live_activity_tokens is
  'Live Activity 푸시 토큰. 활동 단위로 발급/회전하며 APNs로 직접 전송한다.';

create index if not exists live_activity_tokens_match_idx
  on public.live_activity_tokens (match_code);

alter table public.live_activity_tokens enable row level security;

create policy "la_token_select_own" on public.live_activity_tokens
  for select using (auth.uid() = user_id);
create policy "la_token_insert_own" on public.live_activity_tokens
  for insert with check (auth.uid() = user_id);
-- 토큰 회전 시 덮어써야 하므로 UPDATE가 필요하다.
create policy "la_token_update_own" on public.live_activity_tokens
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "la_token_delete_own" on public.live_activity_tokens
  for delete using (auth.uid() = user_id);

create trigger live_activity_tokens_set_updated_at
  before update on public.live_activity_tokens
  for each row execute function public.set_updated_at();

-- ── 2) 전송 큐 ─────────────────────────────────────────────
create table if not exists public.live_activity_events (
  id uuid primary key default gen_random_uuid(),
  match_code text not null,
  -- bwf_live_matches.score와 동일한 jsonb 배열:
  --   [{"set":1,"home":21,"away":14}, ...]  (home=team1, away=team2)
  score jsonb,
  match_status text,
  tournament_status text,
  is_final boolean not null default false,
  status text not null default 'pending',
  error_message text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);
comment on table public.live_activity_events is
  'Live Activity 전송 큐. INSERT를 DB Webhook이 감시해 send-live-activity를 호출한다.';

create index if not exists live_activity_events_pending_idx
  on public.live_activity_events (created_at desc) where status = 'pending';

-- 서버 전용 테이블 — 클라이언트 접근 차단(정책 없음 = 전면 거부).
alter table public.live_activity_events enable row level security;

-- ── 3) 스코어 변경 트리거 ──────────────────────────────────
create or replace function public.notify_live_activity_score()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_is_final boolean;
begin
  if new.match_code is null then
    return new;
  end if;

  -- 10초 폴링 노이즈 차단: 점수와 상태가 모두 그대로면 아무것도 하지 않는다.
  -- (last_polled_at은 매 폴링마다 바뀌므로 비교 대상에서 제외한다.)
  if tg_op = 'UPDATE'
     and coalesce(old.score, 'null'::jsonb) = coalesce(new.score, 'null'::jsonb)
     and coalesce(old.tournament_status, '') = coalesce(new.tournament_status, '')
     and coalesce(old.match_status, '') = coalesce(new.match_status, '')
  then
    return new;
  end if;

  -- 이 경기의 Live Activity 토큰이 하나도 없으면 큐에 넣지 않는다.
  if not exists (
    select 1 from public.live_activity_tokens t
    where t.match_code = new.match_code
  ) then
    return new;
  end if;

  v_is_final := coalesce(new.tournament_status, '') <> 'live';

  insert into public.live_activity_events
    (match_code, score, match_status, tournament_status, is_final)
  values
    (new.match_code, new.score, new.match_status, new.tournament_status, v_is_final);

  return new;
end; $$;

drop trigger if exists trg_notify_live_activity on public.bwf_live_matches;
create trigger trg_notify_live_activity
  after insert or update on public.bwf_live_matches
  for each row
  execute function public.notify_live_activity_score();
