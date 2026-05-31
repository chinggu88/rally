# TASK-006: 대회 참가 선수 페이지

## 목적
대회 상세 페이지의 "대진표 보기" 버튼을 눌렀을 때 이동하는 새로운 화면으로,
해당 대회의 종목별(MS/WS/MD/WD/XD) 참가 선수 목록을 보여준다.

## 데이터 소스
- Supabase Edge Function: `get-tournament-participants`
- 쿼리 파라미터:
  - `tournament_id` (필수, 양수 정수) — `bwf_tournaments.tournament_id`
  - `event_name` (필수) — `MS | WS | MD | WD | XD`
- 응답 스키마:
  ```json
  {
    "tournament_id": 123,
    "event_name": "MS",
    "count": 32,
    "participants": [
      {
        "event_name": "MS",
        "player1_id": 12345,
        "player2_id": null,
        "player1_name": "Viktor Axelsen",
        "player2_name": null,
        "country": "DEN",
        "seed": 1,
        "first_round": "R32",
        "photo_url": "https://..."
      }
    ]
  }
  ```
- 정렬: 서버에서 seed ASC nulls last → player1_name ASC
- 단식(MS/WS): `player2_*` null. 복식(MD/WD/XD): 둘 다 채워짐.

## 작업 분배

### 1) API Agent
**모델 (lib/app/data/models/)**
- `tournament_participant_response.dart` — 참가 항목 단일 모델 (PlayerResponse 패턴: private 필드 + getter/setter + fromJson/toJson)
  - 필드: eventName, player1Id, player2Id, player1Name, player2Name, country, seed, firstRound, photoUrl
  - 편의 getter: `isDoubles` (player2Id != null), `displayName` (단식이면 player1Name, 복식이면 "p1 / p2")
- `get_tournament_participants_response.dart` — 래퍼 모델
  - 필드: tournamentId (int?), eventName (String?), count (int?), participants (List<TournamentParticipantResponse>?)

**레포지토리 (lib/app/data/repositories/tournament_repository.dart)**
- 기존 `TournamentRepository`에 메서드 추가:
  ```dart
  Future<GetTournamentParticipantsResponse> getTournamentParticipants({
    required int tournamentId,
    required String eventName, // MS/WS/MD/WD/XD
  })
  ```
- 기존 `getTournamentMatches` 패턴과 동일하게: 404 → 빈 목록 반환, 200 외 status → Exception throw
- queryParameters: `{ 'tournament_id': '$tournamentId', 'event_name': eventName }`

### 2) Controller Agent
**경로**: `lib/app/modules/match/`

**바인딩** (`bindings/tournament_participants_binding.dart`)
- `TournamentRepository`는 이미 `TournamentDetailBinding`에서 lazyPut되지만,
  직접 이동 가능성도 있으므로 `Get.lazyPut<TournamentRepository>(() => TournamentRepository(), fenix: true)` 보장
- `Get.lazyPut<TournamentParticipantsController>(() => TournamentParticipantsController())`

**컨트롤러** (`controllers/tournament_participants_controller.dart`)
- arguments: `tournament_id` (필수, int), `tournament_name` (선택, String, AppBar 타이틀용)
- 상태(Rx):
  - `selectedEvent` (String): 초기값 'MS'
  - `isLoading` (bool)
  - `errorMessage` (String?)
  - `participants` (List<TournamentParticipantResponse>)
- 동작:
  - onInit에서 arguments 파싱 → 초기 종목으로 fetch
  - `changeEvent(String event)` — 같은 값이면 무시, 다르면 selectedEvent 갱신 + fetch
  - `fetchParticipants()` — TournamentDetailController처럼 race-condition 가드(요청 토큰) 적용
  - `refresh()` — Pull-to-refresh에서 호출

### 3) UI Agent
**뷰** (`views/tournament_participants_view.dart`)
- AppBar: 뒤로가기 + 타이틀(`tournament_name` 또는 "참가 선수")
- 종목 칩 행 (MS / WS / MD / WD / XD) — `player_view.dart`의 카테고리 칩과 동일 패턴
- 로딩: 중앙 CircularProgressIndicator
- 에러: 안내 텍스트 + "다시 시도" 버튼
- 빈 상태: "참가 선수 정보가 아직 공개되지 않았습니다." 안내
- 리스트: 매거진 카드 스타일 (Rally 디자인 — player_view 참고)
  - 좌측: 시드 번호 뱃지 (seed가 null이면 "—")
  - 중앙: 선수 사진(`cached_network_image` + 폴백), 이름, 국가 코드
  - 복식이면 player1/player2 함께 표시
  - 우측 하단: `first_round` 라벨 (R64/R32/R16/QF/SF/F)
- Pull-to-refresh 지원
- 액센트 컬러: 라임 옐로우 `#C3F400` (테마 ColorScheme.primary 사용)

**라우팅** (`lib/app/routes/`)
- `app_routes.dart`: `static const MATCH_PARTICIPANTS = '/match/participants';` 추가
- `app_pages.dart`: GetPage 등록 (binding: TournamentParticipantsBinding)

**연결** (`tournament_detail_view.dart`)
- `_buildBeforeBanner`의 `ctaLabel: '대진표 보기'` onCta를 외부 링크 대신
  `Get.toNamed(Routes.MATCH_PARTICIPANTS, arguments: { 'tournament_id': controller.tournamentId, 'tournament_name': controller.fallback?.name ?? controller.detail?.name })` 로 변경
  (단, `controller.tournamentId == null`이면 비활성화)
- `_buildLiveBanner`의 "실시간 스코어 보기"는 그대로 유지 (외부 링크)
- `_buildCompletedBanner`도 대진표/결과 보기 버튼이 있다면 동일하게 처리 (확인 필요)

## 디자인 가이드
- 폰트: AppTypography (Chivo / Source Sans 3)
- 스페이싱: AppSpacing
- 라운드: AppRadius
- 다크 우선 — `Theme.of(context).colorScheme` 사용
- 종목 칩 선택 상태: 라임 옐로우 배경 + 검정 텍스트
- 카드: surfaceContainerHighest 배경 + 미세한 보더

## 완료 기준
- [ ] tournament_participant_response.dart / get_tournament_participants_response.dart 모델 생성
- [ ] TournamentRepository.getTournamentParticipants() 메서드 추가
- [ ] TournamentParticipantsController / Binding 생성
- [ ] TournamentParticipantsView 생성 (종목 칩 + 리스트 + 로딩/에러/빈상태 + RefreshIndicator)
- [ ] Routes.MATCH_PARTICIPANTS 등록 + AppPages 추가
- [ ] tournament_detail_view "대진표 보기" 버튼 → 새 라우트로 연결
- [ ] flutter analyze 통과
- [ ] docs/architecture.md 업데이트
