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


-- ============================================================
-- Comments (table & column documentation)
-- These are idempotent — safe to re-run.
-- ============================================================

comment on type bwf_category is
  'BWF 종목 코드. MS=남자 단식, WS=여자 단식, MD=남자 복식, WD=여자 복식, XD=혼합 복식.';

comment on table bwf_rankings is
  'BWF 세계 랭킹. batch/jobs/bwf_rankings 잡이 매주 월요일 갱신 (upsert). 키: (category, member_id).';
comment on column bwf_rankings.id            is '내부 surrogate PK (자동 증가).';
comment on column bwf_rankings.category      is '종목 (bwf_category enum).';
comment on column bwf_rankings.rank          is '해당 종목 내 순위 (1부터). 같은 주차에 같은 player가 여러 rank로 응답에 등장 가능해 dedupe 후 최저값 유지.';
comment on column bwf_rankings.member_id     is 'BWF Member ID. 단식은 단일 ID, 복식은 "id1-id2"로 결합. (category, member_id) UNIQUE.';
comment on column bwf_rankings.player_name   is '선수 이름. 복식은 "A / B" 포맷.';
comment on column bwf_rankings.country_code  is 'ISO-3 국가 코드 (예: KOR, CHN). p1_country_model.code_iso3 우선, 없으면 p1_country.';
comment on column bwf_rankings.country_name  is '국가명 (영문). 응답에 있을 때만.';
comment on column bwf_rankings.tournaments   is '최근 52주 동안 참가한 토너먼트 수.';
comment on column bwf_rankings.points        is 'BWF 랭킹 포인트.';
comment on column bwf_rankings.ranking_year  is '랭킹 발표 연도 (publication.year).';
comment on column bwf_rankings.ranking_week  is '랭킹 발표 주차 1~53 (publication.week).';
comment on column bwf_rankings.crawled_at    is '마지막으로 upsert된 시각.';

comment on table batch_logs is
  '모든 배치 작업(bwf_rankings, bwf_calendar 등) 공용 실행 이력. 매 실행마다 1행 insert(status=started) → 종료 시 update(status=success|failed).';
comment on column batch_logs.id            is '내부 PK.';
comment on column batch_logs.job           is '잡 식별자. 예: ''bwf_rankings'', ''bwf_calendar''.';
comment on column batch_logs.status        is '실행 상태. ''started'' | ''success'' | ''failed''.';
comment on column batch_logs.started_at    is '실행 시작 시각 (insert 시 자동).';
comment on column batch_logs.finished_at   is '실행 종료 시각. 진행 중이면 NULL.';
comment on column batch_logs.rows_written  is '성공 시 적재된 행 수. 실패면 부분 진행 수 또는 0.';
comment on column batch_logs.error         is '실패 시 "ExceptionType: 메시지". 성공이면 NULL.';
comment on column batch_logs.metadata      is '잡별 부가 정보 jsonb. 예: bwf_rankings는 {year, week, per_category}, bwf_calendar는 {year, tour_levels_count}.';
