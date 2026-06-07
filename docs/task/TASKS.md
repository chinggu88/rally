# TASK-007: 홈 탭 - 오늘 경기 일정 섹션

## 목적
홈(NewsView) 탭에 "오늘 경기" 섹션을 추가한다.
KST 기준 오늘 하루의 경기 결과(results)와 경기 예정(upcoming)을 한 섹션에서
**탭/칩 토글**로 전환해 매거진 카드 리스트로 보여준다.
라이브 매치 섹션과 뉴스 섹션 사이에 인라인으로 배치한다.

## 데이터 소스
- Supabase Edge Function: `get-today-matches`
- 쿼리 파라미터:
  - `date` (선택, `YYYY-MM-DD`) — 기본값은 서버에서 KST 기준 오늘. 클라이언트는 보통 미지정.
- 응답 스키마:
  ```json
  {
    "date": "2026-06-07",
    "results_count": 12,
    "upcoming_count": 8,
    "results": [
      {
        "id": 123,
        "match_code": "MS1-R32-MATCH-01",
        "tournament_id": 999,
        "tournament_code": "OPEN2026",
        "tournament_status": "live",
        "event_name": "MS",
        "match_type": "Singles",
        "round_name": "Round of 32",
        "team1_country": "DEN",
        "team1_player_ids": [12345],
        "team1_names": ["Viktor Axelsen"],
        "team1_seed": "1",
        "team2_country": "JPN",
        "team2_player_ids": [67890],
        "team2_names": ["Kodai Naraoka"],
        "team2_seed": null,
        "winner": 1,
        "score": [{"set":1,"home":21,"away":18},{"set":2,"home":21,"away":15}],
        "match_status": "completed",
        "match_status_value": "Completed",
        "score_status": null,
        "score_status_value": null,
        "match_time": "2026-06-07T05:30:00+00:00",
        "match_time_utc": "2026-06-07T05:30:00Z",
        "match_time_kst": "2026-06-07T14:30:00+09:00",
        "court_name": "Court 1",
        "location_name": "Arena Hall",
        "duration_min": 52,
        "tournament_name": "Indonesia Open 2026",
        "tournament_logo_url": "https://...",
        "tournament_cat_logo_url": "https://...",
        "tournament_tour_level": "Super 1000",
        "tournament_prize_money_usd": 1450000,
        "tournament_country": "INA",
        "tournament_flag_url": "https://...",
        "tournament_date_label": "Jun 3 - 8, 2026"
      }
    ],
    "upcoming": [/* 동일 스키마, winner/score 없을 수 있음 */]
  }
  ```
- 분류 규칙(서버):
  - `winner=1|2` 또는 `score_status_value in (walkover, retired)` 또는 `score`에 어느 한쪽 점수>0 → `results`
  - 그 외 → `upcoming`
  - `bwf_live_matches`에 있는 `match_code`는 응답에서 **제외** (라이브 섹션과 중복 방지)
- 정렬: `match_time ASC` (results는 응답 시 reverse되어 최근 끝난 게 먼저)

## 작업 분배

### 1) API Agent
**모델 (lib/app/data/models/)**
- `today_match_response.dart` — 단일 항목 모델
  - 패턴: `LiveMatchResponse`와 동일한 private 필드 + getter/setter + fromJson/toJson + 방어적 파싱
  - 핵심 필드:
    - 매치: `id`, `matchCode`, `tournamentId`, `tournamentCode`, `tournamentStatus`,
      `eventName`, `matchType`, `roundName`
    - team1: `team1Names (List<String>?)`, `team1Country`, `team1Seed`, `team1PlayerIds`
    - team2: `team2Names`, `team2Country`, `team2Seed`, `team2PlayerIds`
    - 결과/진행: `winner (int?)`, `score (raw, dynamic→String?로 정규화 후 파싱)`,
      `matchStatus`, `matchStatusValue`, `scoreStatus`, `scoreStatusValue`
    - 일정: `matchTime`, `matchTimeUtc`, `matchTimeKst`, `courtName`, `locationName`, `durationMin`
    - 대회 비정규화: `tournamentName`, `tournamentLogoUrl`, `tournamentCatLogoUrl`,
      `tournamentTourLevel`, `tournamentPrizeMoneyUsd`, `tournamentCountry`,
      `tournamentFlagUrl`, `tournamentDateLabel`
  - 편의 getter:
    - `team1Display` / `team2Display` — `LiveMatchResponse._joinNames`와 동일 로직 ("TBD" 폴백)
    - `displayLogoUrl` — tournamentLogoUrl 우선, 폴백 tournamentCatLogoUrl
    - `matchDateTime` — UTC 우선, 폴백 matchTime
    - `kstDateTime` — matchTimeKst 파싱
    - `winnerSide` — int winner를 1/2로 정규화
    - `games (List<LiveGameScore>)` — score를 `LiveMatchResponse`의 `_parseGames` + 방향 보정 로직 동일하게 적용. `LiveGameScore`는 `live_match_response.dart`의 것을 재사용(import).
    - `isPlayed (bool)` — winner!=null 또는 score에 점수>0 또는 walkover/retired → true
    - `displayKoreanTime` — `kstDateTime`이 있으면 `HH:mm` 포맷 (예: `14:30`), 없으면 null
- `get_today_matches_response.dart` — 래퍼 모델
  - 필드: `date (String?)`, `resultsCount (int?)`, `upcomingCount (int?)`,
    `results (List<TodayMatchResponse>?)`, `upcoming (List<TodayMatchResponse>?)`
  - fromJson에서 `results`/`upcoming` 배열은 빈 배열로 폴백 (null safe)

**레포지토리 (lib/app/data/repositories/today_match_repository.dart)**
- 신규 파일 `TodayMatchRepository`
- 메서드:
  ```dart
  Future<GetTodayMatchesResponse> getTodayMatches({String? date})
  ```
- 패턴: `LiveMatchRepository.getLiveMatches`와 동일
  - `_client.functions.invoke('get-today-matches', method: HttpMethod.get, queryParameters: ...)`
  - 404 → 빈 응답 (`results: [], upcoming: [], counts: 0`)
  - 200 외 → `Exception('get-today-matches failed: status=..., data=...')`
  - `FunctionException` 404도 동일 처리, 그 외는 log + rethrow
  - `date` 파라미터가 null이면 queryParameters에서 생략(서버 기본값 사용)

### 2) Controller Agent
**경로**: `lib/app/modules/news/`

**바인딩** (`bindings/news_binding.dart` 수정)
- 기존 `LiveMatchRepository` lazyPut 아래에
  `Get.lazyPut<TodayMatchRepository>(() => TodayMatchRepository(), fenix: true)` 추가

**컨트롤러** (`controllers/news_controller.dart` 수정 — 신규 클래스 만들지 말고 기존에 통합)
- 추가 의존성: `TodayMatchRepository`를 `Get.find()`로 주입 (lazy)
- 추가 상태(Rx):
  - `_todayMatchesTab` (`RxString`, 'results' | 'upcoming') — 기본값 'results'
  - `_isTodayLoading` (`RxBool`) — 초기 false
  - `_todayError` (`RxnString`)
  - `_todayResults` (`RxList<TodayMatchResponse>`)
  - `_todayUpcoming` (`RxList<TodayMatchResponse>`)
  - `_todayInflightToken` (`int` private) — race-condition 가드
- public getter:
  - `String get todayMatchesTab => _todayMatchesTab.value;`
  - `bool get isTodayLoading => _isTodayLoading.value;`
  - `String? get todayError => _todayError.value;`
  - `List<TodayMatchResponse> get todayResults => _todayResults;`
  - `List<TodayMatchResponse> get todayUpcoming => _todayUpcoming;`
  - `List<TodayMatchResponse> get todayCurrent =>
      _todayMatchesTab.value == 'results' ? _todayResults : _todayUpcoming;`
- 동작:
  - `onInit()` 끝에서 `fetchTodayMatches()` 호출 (라이브 매치 fetch와 병렬 가능)
  - `Future<void> fetchTodayMatches()` — 토큰 증가 → loading true → 조회 → 토큰 일치 시 list 갱신 + loading false. 실패 시 error 세팅. 빈 리스트라도 에러 아님.
  - `void changeTodayTab(String tab)` — 'results' 또는 'upcoming'만 허용, 동일값 무시
  - `Future<void> refreshLiveMatches()` 안에서 라이브 갱신과 함께 `fetchTodayMatches()`도 await (Pull-to-refresh가 같이 갱신되도록)
- 기존 라이브 매치/뉴스카드 로직은 유지(추가만)

### 3) UI Agent
**뷰** (`views/news_view.dart` 수정)
- 라이브 섹션과 뉴스 섹션 사이에 "오늘 경기" 섹션 SliverToBoxAdapter 추가
  - 순서: `[active_tournaments] → [live] → [today_matches] → [news]`
  - 섹션 위에 `SizedBox(height: 24)` 간격 유지
- 섹션 헤더:
  - 좌측 아이콘 점(라이브와 구분 — 라임 옐로우 도트) + "오늘 경기" 텍스트 (라이브 섹션 헤더와 동일 스타일)
  - 우측에 토글 칩 2개: `경기 결과` / `경기 예정` (선택 상태: 라임 옐로우 배경 + 검정 텍스트 / 비선택: 투명 + 흰 텍스트 + 보더)
    - 라이브 섹션 헤더의 LIVE/OFF dot 위치에 둠
- 본문:
  - 로딩 (results/upcoming 둘 다 비어있고 isTodayLoading=true): 220 높이 CircularProgressIndicator
  - 에러 + 빈 리스트: 라이브와 동일한 에러 카드 (다시 시도 버튼이 `controller.fetchTodayMatches`)
  - 빈 상태: "오늘은 더 표시할 경기가 없습니다." + 부제 "결과가 등록되거나 새로운 경기가 추가되면 표시됩니다."
  - 리스트: 매거진 카드 (세로 리스트, `padding: EdgeInsets.symmetric(horizontal: 20)`)
- 카드 위젯 신규: `views/widgets/today_match_card.dart`
  - 전체 컨테이너: `surfaceContainerHighest` 톤 (`#1C1B1B` 정도) + 16 라운드 + 1px 보더(`#2A2A2A`)
  - 상단 행: 대회 로고(24px, `cached_network_image`, 실패 시 회색 박스) + 대회명(1줄, ellipsis, Chivo 12 w800) + 우측에 종목 칩(예: `MS`, 11px, accentDark 배경 + accent 텍스트)
  - 중앙 행: 좌측 team1 / 가운데 결과 또는 시간 / 우측 team2
    - team1/team2 각각 세로 정렬: 국가코드(또는 flag emoji)·시드(seed가 있으면 `[1]`) → 이름들(복식이면 두 줄)
    - results 탭에서 isPlayed=true이면 가운데에 게임별 스코어 pill (`games`의 team1-team2 표시), 승자 쪽 이름은 accent 컬러로 강조
    - upcoming 탭에서는 가운데에 `displayKoreanTime` (예: `14:30 KST`) + 그 아래 코트명 작게
    - walkover/retired는 스코어 pill 자리에 라벨로 표시
  - 하단 행: round_name(좌측, 10px, subtleText) · location_name/court_name(우측, 10px, subtleText)
- Pull-to-refresh: 기존 `controller.refreshLiveMatches`가 today도 함께 갱신하도록 컨트롤러에서 처리됨 → UI 변경 불필요

**라우팅**: 신규 라우트 없음 (홈 인라인 섹션).

## 디자인 가이드
- 폰트: AppTypography (Chivo / Source Sans 3)
- 스페이싱: AppSpacing (필요 시 EdgeInsets 직접값)
- 라운드: 16 (카드), 999 (pill/chip)
- 다크 우선 — `Theme.of(context).colorScheme` 또는 `AppColors.dark`
- 토글 칩 선택 상태: 라임 옐로우 배경 + accentDark 텍스트
- 카드: 1C1B1B 배경 + 2A2A2A 보더
- 승자 강조: 라임 옐로우 텍스트

## 완료 기준
- [x] `today_match_response.dart` / `get_today_matches_response.dart` 모델 생성
- [x] `TodayMatchRepository.getTodayMatches()` 메서드 추가
- [x] `NewsBinding`에 `TodayMatchRepository` 등록
- [x] `NewsController`에 today 상태/메서드 추가, `refreshLiveMatches`가 today도 갱신
- [x] `news_view.dart`에 오늘 경기 섹션 추가 + 탭 토글 + 로딩/에러/빈상태
- [x] `today_match_card.dart` 위젯 생성
- [x] `flutter analyze` 통과
- [ ] `docs/architecture.md` 업데이트 (모델 / 레포지토리 / Edge Function 매핑 / 화면 플로우 — 홈 섹션 추가)
