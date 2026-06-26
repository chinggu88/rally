-- 라이브 매치 채팅 메시지 테이블 + RLS + Realtime.
--
-- 홈(뉴스) 탭의 라이브 매치 카드 탭 → 채팅방 진입 → 다수 유저가 실시간으로 응원/대화.
-- 경기 종료 후에도 메시지는 영구 보존(재유입 사용자에게 응원 기록 보존).
--
-- 1) 메시지 테이블 + content 길이 제약(1~500자)
-- 2) RLS: SELECT 공개(로그인 강제는 클라이언트가 진입 시 차단), INSERT/DELETE는 본인만
-- 3) Realtime publication 등록 + REPLICA IDENTITY FULL

-- ── 1) 테이블 ────────────────────────────────────────────────
create table if not exists public.live_match_chat_messages (
  id            uuid primary key default gen_random_uuid(),
  live_match_id bigint not null references public.bwf_live_matches(id) on delete cascade,
  user_id       uuid   not null references auth.users(id) on delete cascade,
  content       text   not null check (char_length(content) between 1 and 500),
  created_at    timestamptz not null default now()
);
comment on table public.live_match_chat_messages is
  '라이브 매치 채팅방 메시지. 경기 종료 후에도 영구 보존.';

create index if not exists live_match_chat_messages_match_created_idx
  on public.live_match_chat_messages (live_match_id, created_at desc);

-- ── 2) RLS ───────────────────────────────────────────────────
alter table public.live_match_chat_messages enable row level security;

drop policy if exists "lmc_select_all" on public.live_match_chat_messages;
create policy "lmc_select_all" on public.live_match_chat_messages
  for select
  to anon, authenticated
  using (true);

drop policy if exists "lmc_insert_self" on public.live_match_chat_messages;
create policy "lmc_insert_self" on public.live_match_chat_messages
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "lmc_delete_own" on public.live_match_chat_messages;
create policy "lmc_delete_own" on public.live_match_chat_messages
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- ── 3) Realtime ──────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_match_chat_messages'
  ) then
    alter publication supabase_realtime add table public.live_match_chat_messages;
  end if;
end
$$;

alter table public.live_match_chat_messages replica identity full;
