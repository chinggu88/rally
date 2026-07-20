-- 관심 선수 라이브 경기 시작 푸시 알림.
--
-- bwf_live_matches에 새 라이브 매치가 INSERT되거나 post→live로 재승격될 때,
-- 해당 매치의 선수를 즐겨찾기한(favorite_players) 유저 중 알림 활성
-- (profiles.notifications_enabled) 유저에게 notifications 행을 INSERT한다.
-- notifications INSERT는 기존 DB Webhook(send-push-on-notification)이 받아
-- send-push Edge Function으로 FCM 발송한다.
--
-- 중복 정책: 유저+매치 조합당 1회만 (재승격돼도 재알림 없음) — 부분 유니크
-- 인덱스 + ON CONFLICT DO NOTHING.

-- ── 1) 유저+매치당 1회 유니크 인덱스 ─────────────────────────
create unique index if not exists notifications_live_match_start_unique
  on public.notifications (user_id, ((data->>'live_match_id')))
  where (data->>'type') = 'live_match_start';

-- ── 2) 트리거 함수 ──────────────────────────────────────────
create or replace function public.notify_favorite_player_live_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_ids bigint[];
begin
  -- 배치 워커가 10초마다 같은 live row를 upsert(UPDATE)하므로
  -- live→live UPDATE는 즉시 무시 (WHEN 절에서는 INSERT 시 OLD 참조 불가라 여기서 분기).
  if tg_op = 'UPDATE' and old.tournament_status = 'live' then
    return new;
  end if;

  v_player_ids :=
    coalesce(new.team1_player_ids, '{}') || coalesce(new.team2_player_ids, '{}');
  if array_length(v_player_ids, 1) is null then
    return new;
  end if;

  insert into public.notifications (user_id, title, body, data)
  select
    fp.user_id,
    '관심 선수 경기 시작',
    coalesce(
      nullif(
        array_to_string(
          array_agg(distinct fp.player_name)
            filter (where fp.player_name is not null),
          ', '
        ),
        ''
      ),
      '관심 선수'
    )
      || ' 선수의 라이브 경기가 시작되었습니다'
      || coalesce(' · ' || new.name, ''),
    jsonb_build_object(
      'type', 'live_match_start',
      'live_match_id', new.id,
      'tournament_id', new.tournament_id,
      'tournament_name', new.name,
      'event_name', new.event_name,
      'round_name', new.round_name,
      'player_names',
        to_jsonb(
          array_agg(distinct fp.player_name)
            filter (where fp.player_name is not null)
        )
    )
  from public.favorite_players fp
  join public.profiles p
    on p.id = fp.user_id
   and p.notifications_enabled
  where fp.player_id = any(v_player_ids)
  group by fp.user_id
  on conflict (user_id, ((data->>'live_match_id')))
    where (data->>'type') = 'live_match_start'
    do nothing;

  return new;
end;
$$;

-- ── 3) 트리거 ───────────────────────────────────────────────
drop trigger if exists trg_notify_favorite_live_match on public.bwf_live_matches;

create trigger trg_notify_favorite_live_match
  after insert or update of tournament_status on public.bwf_live_matches
  for each row
  when (new.tournament_status = 'live')
  execute function public.notify_favorite_player_live_match();
