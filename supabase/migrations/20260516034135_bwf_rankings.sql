create type bwf_category as enum ('MS', 'WS', 'MD', 'WD', 'XD');

create table bwf_rankings (
  id              bigserial primary key,
  category        bwf_category not null,
  rank            int not null,
  member_id       text not null,
  player_name     text not null,
  country_code    text,
  country_name    text,
  tournaments     int,
  points          numeric(10, 2) not null,
  ranking_year    int not null,
  ranking_week    int not null,
  crawled_at      timestamptz not null default now(),
  unique (category, member_id)
);

create index bwf_rankings_category_rank_idx on bwf_rankings (category, rank);
create index bwf_rankings_week_idx on bwf_rankings (ranking_year, ranking_week);

create table batch_logs (
  id           bigserial primary key,
  job          text not null,
  status       text not null,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  rows_written int,
  error        text,
  metadata     jsonb
);

create index batch_logs_job_started_idx on batch_logs (job, started_at desc);
