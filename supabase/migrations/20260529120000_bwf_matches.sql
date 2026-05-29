-- BWF tournament matches: one row per match within a tournament draw.
-- Source: extranet vue-tournament-draw-data ("matches" array), crawled per
-- tournament/draw. A match belongs to one tournament (bwf_tournaments) and one
-- discipline draw (MS/WS/MD/WD/XD).
--
-- Tournament lifecycle is captured per-crawl via tournament_status, derived from
-- the calendar API's live_status:
--   'pre'  = 대회전  (draw published, no matches played yet → matchStatusValue 'none')
--   'live' = 대회중  (mix of Finished + none)
--   'post' = 대회후  (all Finished)
create table bwf_matches (
  id                bigint primary key,             -- BWF match.id (stable, not a sequence)
  match_code        text,                           -- match.code (unique within tournament)
  tournament_id     integer not null,               -- FK target: bwf_tournaments.tournament_id
  tournament_code   text,                           -- BWF GUID
  tournament_status text,                            -- 'pre' | 'live' | 'post' (snapshot at crawl)

  -- Draw / discipline
  draw_id           text,                           -- vue-tournament-draws.value (per-tournament)
  draw_code         text,                           -- match.drawCode
  event_name        text,                           -- 'MS' | 'WS' | 'MD' | 'WD' | 'XD'
  match_type        text,                           -- "Men's Doubles", etc.
  round_name        text,                           -- 'R32' | 'QF' | 'SF' | 'F' ...

  -- Status / result
  match_status      text,                           -- 'F' | 'none' | ... (match.matchStatus)
  match_status_value text,                           -- 'Finished' | 'none' | ...
  score_status      integer,                        -- match.scoreStatus (0 = Normal)
  score_status_value text,                           -- 'Normal' | 'Walkover' | 'Retired' ...
  winner            integer,                        -- 1 | 2 | NULL (which team won)

  -- Players (denormalized for fast reads; full objects in raw)
  team1_country     text,
  team2_country     text,
  team1_player_ids  bigint[],                       -- 1 (singles) or 2 (doubles) ids
  team2_player_ids  bigint[],
  team1_names       text[],                         -- nameDisplay per player
  team2_names       text[],
  team1_seed        text,
  team2_seed        text,

  -- Scores: [{set, home, away}, ...]
  score             jsonb,

  -- Scheduling
  match_time        timestamptz,                    -- local (match.matchTime)
  match_time_utc    timestamptz,                    -- UTC (match.matchTimeUtc)
  duration_min      integer,                        -- match.duration
  court_name        text,
  location_name     text,

  -- Provenance
  raw               jsonb not null default '{}'::jsonb,
  crawled_at        timestamptz not null default now()
);

create index bwf_matches_tournament_idx on bwf_matches (tournament_id);
create index bwf_matches_status_idx on bwf_matches (tournament_status);
create index bwf_matches_event_idx on bwf_matches (event_name);
create index bwf_matches_round_idx on bwf_matches (round_name);
create index bwf_matches_match_time_idx on bwf_matches (match_time);
create index bwf_matches_team1_players_idx on bwf_matches using gin (team1_player_ids);
create index bwf_matches_team2_players_idx on bwf_matches using gin (team2_player_ids);

alter table bwf_matches enable row level security;

grant select on table bwf_matches to anon;
grant select on table bwf_matches to authenticated;
grant all on table bwf_matches to service_role;
