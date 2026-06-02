-- bwf_live_matches에 라이브 대회 카드 표시용 컬럼 추가.
-- 워커가 한 대회당 한 row를 박는 구조(id=tournament_id)에서, 클라이언트가 부모
-- bwf_tournaments와 JOIN하지 않고도 라이브 카드를 그릴 수 있게 핫패스 필드를
-- 직접 둔다. raw jsonb에는 원본 그대로 보존돼 있지만 정렬/필터/UI 바인딩에는
-- 정식 컬럼이 필요.
--
-- 모두 nullable: 진짜 매치 row가 들어올 경우(미래)에는 이 컬럼들이 비어있을 수
-- 있어야 하고, BWF가 일부 필드를 빼도 적재가 깨지면 안 된다.
alter table bwf_live_matches
  add column if not exists slug                    text,
  add column if not exists name                    text,
  add column if not exists start_date              date,
  add column if not exists end_date                date,
  add column if not exists date_label              text,
  add column if not exists prize_money_usd         numeric(12,2),
  add column if not exists detail_url              text,
  add column if not exists logo_url                text,
  add column if not exists header_image_url        text,
  add column if not exists header_image_mobile_url text,
  add column if not exists cat_logo_url            text,
  add column if not exists category_name           text,
  add column if not exists tournament_category_id  integer,
  add column if not exists tournament_series_id    integer,
  add column if not exists is_etihad               boolean;

-- 현재 라이브 대회를 시작일 기준으로 정렬하는 흔한 쿼리 대응.
create index if not exists bwf_live_matches_start_date_idx
  on bwf_live_matches (start_date);
