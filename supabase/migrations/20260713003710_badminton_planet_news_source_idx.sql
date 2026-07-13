-- 소스별 카드뉴스 페이지네이션용 (get-news-cards ?source= 필터).
-- card_created=true 행만 대상으로 하는 부분 인덱스. 정렬 tiebreaker(id desc) 포함.
create index badminton_planet_news_source_published_idx
  on badminton_planet_news (source, published_at desc, id desc)
  where card_created = true;
