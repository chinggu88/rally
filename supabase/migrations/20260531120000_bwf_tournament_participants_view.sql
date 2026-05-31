-- BWF 대회별 참가 선수(participants) view.
--
-- Source: `bwf_matches`의 team1/team2 player_ids/names/seed/event.
-- 같은 대회 + 종목 + 선수 조합이 여러 라운드에 걸쳐 나타나므로 distinct on으로
-- 한 row만 남긴다. seed가 가장 처음 등장하는 라운드(보통 R32/R16)의 값을 채택.
--
-- 단식: team의 player_ids 배열 길이 1 -> participant row 1개 (player1만 채워짐)
-- 복식: 배열 길이 2 -> participant row 1개 (player1 + player2)
--
-- 한계: bwf_matches에 등장하지 않는 선수는 누락된다. 즉
--   - 대진 발표 전 신청 단계의 entry list는 표시 불가
--   - 대진 발표 전 기권자는 표시 불가
-- BWF가 entries 전용 public API를 제공하지 않아 위 케이스는 현재 데이터 소스로
-- 표현 불가능하다. 추후 별도 entry list 소스가 생기면 보조 테이블로 보완 권장.
create or replace view bwf_tournament_participants_view as
with team_rows as (
  -- team1 측 row를 페어 단위로 평탄화
  select
    tournament_id,
    event_name,
    round_name,
    match_time,
    team1_player_ids[1] as player1_id,
    team1_player_ids[2] as player2_id,
    team1_names[1]      as player1_name,
    team1_names[2]      as player2_name,
    team1_country       as country,
    team1_seed          as seed
  from bwf_matches
  where team1_player_ids is not null
    and array_length(team1_player_ids, 1) >= 1

  union all

  -- team2 측 row
  select
    tournament_id,
    event_name,
    round_name,
    match_time,
    team2_player_ids[1] as player1_id,
    team2_player_ids[2] as player2_id,
    team2_names[1]      as player1_name,
    team2_names[2]      as player2_name,
    team2_country       as country,
    team2_seed          as seed
  from bwf_matches
  where team2_player_ids is not null
    and array_length(team2_player_ids, 1) >= 1
)
-- 같은 대회/종목/선수(페어) 조합은 가장 이른 라운드(가장 빠른 match_time)만 채택.
-- 가장 이른 라운드의 seed가 가장 정확하다 (이후 walkover/withdrawal로 변하지 않은 값).
select distinct on (tournament_id, event_name, player1_id, coalesce(player2_id, 0))
  tournament_id,
  event_name,
  player1_id,
  player2_id,
  player1_name,
  player2_name,
  country,
  seed,
  round_name as first_round
from team_rows
where player1_id is not null
order by tournament_id, event_name, player1_id, coalesce(player2_id, 0),
         match_time asc nulls last;

comment on view bwf_tournament_participants_view is
  'bwf_matches에서 derive한 대회/종목별 참가 선수(페어) 명단. '
  '단식은 player1만, 복식은 player1+player2. seed는 가장 이른 라운드 값.';

grant select on bwf_tournament_participants_view to anon;
grant select on bwf_tournament_participants_view to authenticated;
grant select on bwf_tournament_participants_view to service_role;
