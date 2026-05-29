-- BWF player profiles: one row per BWF player.
-- Singles ranking rows reference player1_id only; doubles rows reference both.
create table bwf_players (
  id              bigint primary key,             -- BWF player.id (not a sequence)
  name_display    text not null,
  first_name      text,
  last_name       text,
  gender          text,                           -- 'M' | 'F' | NULL (XD partner ambiguous)
  country_code    text,                           -- ISO3
  country_name    text,

  -- Enriched detail fields (all nullable; populated by detail-page crawl)
  birthday        date,
  height_cm       int,
  handedness      text,                           -- 'right' | 'left' | 'ambidextrous'
  photo_url       text,
  bio             text,
  coach           text,
  birthplace      text,
  plays           text,                           -- 'Singles' | 'Doubles' | 'Both'
  career_titles   int,
  career_wins     int,
  career_losses   int,
  social_links    jsonb,                          -- {instagram, twitter, facebook, ...}

  -- Provenance
  detail_url      text,
  raw             jsonb not null default '{}'::jsonb,
  detail_fetched_at timestamptz,                  -- NULL = not yet enriched / retry candidate
  crawled_at      timestamptz not null default now()
);

create index bwf_players_country_idx on bwf_players (country_code);
create index bwf_players_name_idx on bwf_players (name_display);
create index bwf_players_detail_fetched_idx on bwf_players (detail_fetched_at);

alter table bwf_players enable row level security;

-- Add FK columns to bwf_rankings linking each ranking row to one or two players.
alter table bwf_rankings
  add column player1_id bigint,
  add column player2_id bigint;

alter table bwf_rankings
  add constraint bwf_rankings_player1_fk
    foreign key (player1_id) references bwf_players(id)
    on delete set null deferrable initially deferred,
  add constraint bwf_rankings_player2_fk
    foreign key (player2_id) references bwf_players(id)
    on delete set null deferrable initially deferred;

create index bwf_rankings_player1_idx on bwf_rankings (player1_id);
create index bwf_rankings_player2_idx on bwf_rankings (player2_id);

-- Backfill helper: splits member_id ("123" or "123-456") into player1_id/player2_id.
-- Called by the batch job after upserting bwf_players so all rankings rows get
-- their FK populated in a single round-trip.
create or replace function bwf_backfill_ranking_player_ids() returns int as $$
declare
  updated int;
begin
  update bwf_rankings
    set player1_id = split_part(member_id, '-', 1)::bigint,
        player2_id = nullif(split_part(member_id, '-', 2), '')::bigint
    where member_id ~ '^\d+(-\d+)?$'
      and (player1_id is null or player2_id is null);
  get diagnostics updated = row_count;
  return updated;
end;
$$ language plpgsql;
