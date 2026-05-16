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
