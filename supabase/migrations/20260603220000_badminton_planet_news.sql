-- badmintonplanet.com 뉴스 기사: 기사 1건당 1행.
-- batch/jobs/badminton_planet_news 크롤러가 url을 자연키로 upsert 한다.
create table badminton_planet_news (
  id            bigserial primary key,
  url           text not null unique,                 -- 기사 원문 링크 (upsert on_conflict 키)
  title         text not null,
  author        text,
  category      text,
  published_at  timestamptz,                           -- <time datetime="..."> ISO8601
  source        text not null default 'badmintonplanet.com',
  raw           jsonb not null default '{}'::jsonb,     -- 파싱 원본 메타
  crawled_at    timestamptz not null default now()
);

create index badminton_planet_news_published_idx
  on badminton_planet_news (published_at desc);

alter table badminton_planet_news enable row level security;
