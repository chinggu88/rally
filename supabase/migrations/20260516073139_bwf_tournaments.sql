create type bwf_tour_level as enum (
  'FINALS',
  'SUPER_1000',
  'SUPER_750',
  'SUPER_500',
  'SUPER_300'
);

create table bwf_tournaments (
  id                 bigserial primary key,
  tournament_id      int not null unique,
  code               text,
  name               text not null,
  tour_level         bwf_tour_level not null,
  category_id        int not null,
  start_date         date,
  end_date           date,
  date_label         text,
  country            text,
  location           text,
  prize_money_usd    numeric(12, 2),
  detail_url         text,
  flag_url           text,
  logo_url           text,
  cat_logo_url       text,
  status             text,
  has_live_scores    boolean,
  year               int not null,
  raw                jsonb not null default '{}'::jsonb,
  crawled_at         timestamptz not null default now()
);

create index bwf_tournaments_year_idx        on bwf_tournaments (year);
create index bwf_tournaments_tour_level_idx on bwf_tournaments (tour_level);
create index bwf_tournaments_start_date_idx on bwf_tournaments (start_date);


-- ============================================================
-- Comments (table & column documentation)
-- These are idempotent — safe to re-run.
-- ============================================================

comment on type bwf_tour_level is
  'HSBC BWF World Tour 등급. FINALS, SUPER_1000, SUPER_750, SUPER_500, SUPER_300.';

comment on table bwf_tournaments is
  'HSBC BWF World Tour 토너먼트 일정. batch/jobs/bwf_calendar 잡이 수동/주기적으로 갱신 (upsert). 키: tournament_id.';
comment on column bwf_tournaments.id              is '내부 surrogate PK (자동 증가).';
comment on column bwf_tournaments.tournament_id   is 'BWF API의 토너먼트 ID (예: 5227). UNIQUE — upsert의 conflict 키.';
comment on column bwf_tournaments.code            is 'BWF API의 토너먼트 UUID 문자열 (예: 41287386-9043-...).';
comment on column bwf_tournaments.name            is '대회명 (예: "PETRONAS Malaysia Open 2026").';
comment on column bwf_tournaments.tour_level      is '월드투어 등급 (bwf_tour_level enum). API category 라벨 또는 cat_logo의 suffix에서 도출.';
comment on column bwf_tournaments.category_id     is 'enum→정수 매핑값. FINALS=8, SUPER_1000=9, SUPER_750=10, SUPER_500=11, SUPER_300=12. (BWF의 group ID와는 다름 — 내부 표기용)';
comment on column bwf_tournaments.start_date      is '대회 시작일 (YYYY-MM-DD). API의 start_date에서 date만 추출.';
comment on column bwf_tournaments.end_date        is '대회 종료일 (YYYY-MM-DD).';
comment on column bwf_tournaments.date_label      is 'BWF가 표시하는 기간 텍스트 원문 (예: "06  - 11 Jan"). 표기에 그대로 쓰고 싶을 때 사용.';
comment on column bwf_tournaments.country         is '국가명 (영문, 예: "Malaysia").';
comment on column bwf_tournaments.location        is '도시 + 국가 (예: "Kuala Lumpur, Malaysia").';
comment on column bwf_tournaments.prize_money_usd is '총상금 USD. API "1,450,000" 문자열 → 1450000.00 변환.';
comment on column bwf_tournaments.detail_url      is '대회 상세 페이지 URL.';
comment on column bwf_tournaments.flag_url        is '국기 이미지 URL.';
comment on column bwf_tournaments.logo_url        is '대회 로고 이미지 URL.';
comment on column bwf_tournaments.cat_logo_url    is '등급 로고 SVG URL (suffix_1000_white-01.svg 등). enum 도출에도 사용.';
comment on column bwf_tournaments.status          is '대회 상태 라벨. 예: "Normal", "Cancelled". API의 status 객체에서 label만 추출.';
comment on column bwf_tournaments.has_live_scores is 'BWF live score 페이지 제공 여부.';
comment on column bwf_tournaments.year            is '시즌 연도. CLI --year 또는 기본 datetime.now().year.';
comment on column bwf_tournaments.raw             is 'API 원본 토너먼트 JSON 전체. 신규 필드 추가/디버깅용 안전망.';
comment on column bwf_tournaments.crawled_at      is '마지막으로 upsert된 시각.';
