-- 카드뉴스 생성 여부 플래그. 기사 url 기준으로 카드뉴스가 만들어졌는지 판단한다.
alter table badminton_planet_news
  add column card_created boolean not null default false;

-- 아직 카드뉴스가 안 만들어진 기사 조회용 (배치에서 미생성 건만 집어올 때).
create index badminton_planet_news_card_created_idx
  on badminton_planet_news (card_created)
  where card_created = false;
