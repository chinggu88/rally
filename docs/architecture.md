```
rally/lib/
├── main.dart                                              # 앱 진입점 — dotenv.load / Supabase.initialize / GetMaterialApp
│
├── app/                                                   # [앱 메인] 애플리케이션 로직
│   │
│   ├── routes/                                            # [라우팅] GetX 네비게이션
│   │   ├── app_pages.dart                                 # GetPage 매핑 (app/news/match/player/my_info/login/sign_up)
│   │   └── app_routes.dart                                # 라우트 경로 상수 (APP / NEWS / MATCH / PLAYER / MY_INFO / LOGIN / SIGN_UP)
│   │
│   ├── data/                                              # [데이터 레이어] 모델 + 레포지토리 (Supabase Edge Function 연동)
│   │   ├── models/
│   │   │   ├── tournament_response.dart                   # BWF 대회 단일 응답 모델 (private 필드 + getter/setter)
│   │   │   ├── get_tournaments_response.dart              # { year, count, tournaments } 래퍼 모델
│   │   │   ├── tournament_detail_response.dart            # 대회 상세 정보 모델 (배너 + 경기 배열)
│   │   │   ├── tournament_match_response.dart             # 대회의 단일 경기 모델 (선수/일정 정보)
│   │   │   ├── get_tournament_matches_response.dart       # { tournament_id, event_name, count, matches } 래퍼 모델
│   │   │   ├── tournament_participant_response.dart       # 종목별 참가 선수 단일 모델 (eventName/player1Id/name/country/seed 등) — TASK-006
│   │   │   ├── get_tournament_participants_response.dart  # { tournament_id, event_name, count, participants } 래퍼 모델 — TASK-006
│   │   │   ├── player_response.dart                       # BWF 선수 단일 응답 모델 (private 필드 + getter/setter)
│   │   │   ├── get_players_response.dart                  # { category, count, players } 래퍼 모델
│   │   │   ├── player_detail_response.dart                # 선수 상세 정보 모델 (랭킹/성적 등)
│   │   │   └── get_player_response.dart                   # 선수 단일 상세 조회 래퍼 모델
│   │   │
│   │   └── repositories/
│   │       ├── tournament_repository.dart                 # Edge Function `get-tournaments` / `get-tournament` / `get-tournament-matches` / `get-tournament-participants` 호출
│   │       └── player_repository.dart                     # Edge Function `get-players` / `get-player` 호출 (카테고리별 조회: MS/WS/MD/WD/XD)
│   │
│   └── modules/                                           # [모듈] 기능별 MVC 패턴 구현
│       │
│       ├── app/                                           # [앱 셸] 바텀네비를 호스팅하는 루트 화면
│       │   ├── bindings/app_binding.dart                  # 바텀네비 전체 모듈 바인딩
│       │   ├── controllers/app_controller.dart            # 탭 전환 상태 관리
│       │   └── views/app_view.dart                        # 바텀네비 + 페이지 호스트
│       │
│       ├── news/                                          # [뉴스] 바텀네비 1번 탭 (placeholder)
│       │   ├── bindings/news_binding.dart
│       │   ├── controllers/news_controller.dart
│       │   └── views/news_view.dart
│       │
│       ├── match/                                         # [경기] 국제 대회 리스트 + 상세 + 참가 선수 — TASK-004~006
│       │   ├── bindings/match_binding.dart                # TournamentRepository + MatchController lazyPut
│       │   ├── controllers/match_controller.dart          # 연도별 대회 fetch / 로딩·에러 상태 / 외부 링크 오픈
│       │   ├── views/match_view.dart                      # 매거진 카드 리스트 + 연도 선택 + Pull-to-refresh (Stitch 225c4429594e4cb3835b154cbc861919)
│       │   ├── bindings/tournament_detail_binding.dart    # TournamentRepository(fenix) + TournamentDetailController lazyPut
│       │   ├── controllers/tournament_detail_controller.dart # 대회별 경기 fetch / 종목 칩 전환 / race-condition 가드
│       │   ├── views/tournament_detail_view.dart          # 종목 칩(MS/WS/MD/WD/XD) + 경기 리스트 + "대진표 보기" CTA
│       │   ├── bindings/tournament_participants_binding.dart # TournamentRepository(fenix) + TournamentParticipantsController lazyPut — TASK-006
│       │   ├── controllers/tournament_participants_controller.dart # 종목별 참가 선수 fetch / 종목 칩 전환 / race-condition 가드(_inflightToken) — TASK-006
│       │   └── views/tournament_participants_view.dart    # 종목 칩(MS/WS/MD/WD/XD) + 참가 선수 매거진 카드 리스트 + Pull-to-refresh — TASK-006
│       │
│       ├── player/                                        # [선수] BWF 랭킹 선수 리스트 (매거진) — TASK-005
│       │   ├── bindings/player_binding.dart                # PlayerRepository + PlayerController lazyPut
│       │   ├── controllers/player_controller.dart          # 카테고리별 선수 fetch / 로딩·에러 상태 / 카테고리 전환 / race-condition 가드
│       │   └── views/player_view.dart                      # 매거진 카드 리스트 + 카테고리 칩(MS/WS/MD/WD/XD) + Pull-to-refresh (Stitch eeae55cab3614d408743636d325e3b88)
│       │
│       ├── my_info/                                       # [내 정보] 비로그인 상태 진입 화면 — TASK-001
│       │   ├── bindings/my_info_binding.dart
│       │   ├── controllers/my_info_controller.dart        # goToLogin / goToSignUp / isLoggedIn placeholder
│       │   └── views/my_info_view.dart                    # 다크 + 라임 옐로우 안내 화면 (Stitch 8329646c315c48fdb5bfa15f9a643418)
│       │
│       ├── login/                                         # [로그인] 이메일/비밀번호 폼 — TASK-002
│       │   ├── bindings/login_binding.dart
│       │   ├── controllers/login_controller.dart          # TextEditingController 관리 + 이메일/비밀번호 유효성
│       │   └── views/login_view.dart                      # Stitch a7cf71e767ad4610a93373028a9c3ab0
│       │
│       └── sign_up/                                       # [회원가입] 이메일 인증 화면 — TASK-003
│           ├── bindings/sign_up_binding.dart
│           ├── controllers/sign_up_controller.dart        # 이메일/인증코드 입력 + 타이머 placeholder
│           └── views/sign_up_view.dart                    # Stitch 3616350c62da4e95906ab4d458eb7ebc
│
├── services/                                              # [글로벌 서비스] GetxService 기반 싱글톤
│   └── supabase_service.dart                              # Supabase 클라이언트 부팅 (.env의 URL/anon key 로드 + Get.put)
│
└── theme/                                                 # [디자인 토큰] 다크/라이트 ColorScheme + 타이포 + 스페이싱
    ├── app_colors.dart                                    # ColorScheme.dark/light (액센트: 라임 옐로우 #C3F400)
    ├── app_typography.dart                                # Chivo / Source Sans 3 기반 TextStyle 세트
    ├── app_spacing.dart                                   # AppSpacing(base/container/stackGap) + AppRadius(sm~full)
    └── app_theme.dart                                     # ThemeData 빌더 (Material 3 + 다크 우선)
```

## 화면 플로우

```
[AppView (바텀네비)]
   │
   ├── 뉴스(News)               — placeholder
   ├── 경기(Match)               ─► [MatchView] 대회 리스트
   │                              │
   │                              └─► [TournamentDetailView] 대회 상세 (경기 배열)
   │                                   │
   │                                   └─► "대진표 보기" CTA ─► [TournamentParticipantsView] 참가 선수 (종목별) — TASK-006
   │
   ├── 선수(Player)              ─► BWF 랭킹 선수 리스트 (매거진, get-players Edge Function)
   │                              │
   │                              └─► [PlayerDetailView] 선수 상세
   │
   └── 내정보(MyInfo)
            │
            └── 로그인 버튼 ─► [LoginView] ─► "회원가입" ─► [SignUpView (이메일 인증)]
```

## 데이터 레이어 / 외부 의존성

- **API 호출 방식**: 모든 API는 Supabase Edge Function (`Supabase.instance.client.functions.invoke('<name>')`) 경유. Dio·http·PostgREST 직접 접근 금지.
- **.env 키**: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (rally 루트 `.env`). 누락 시 SupabaseService.initialize가 경고 로그만 남기고 정상 부팅.
- **Edge Function 매핑**:
  - `match` 모듈 ↔ `supabase/functions/get-tournaments` (대회 목록)
  - `match` 모듈 ↔ `supabase/functions/get-tournament` (대회 상세)
  - `match` 모듈 ↔ `supabase/functions/get-tournament-matches` (경기 목록)
  - `match` 모듈 ↔ `supabase/functions/get-tournament-participants` (참가 선수, 종목별) — TASK-006
  - `player` 모듈 ↔ `supabase/functions/get-players` (선수 목록)
  - `player` 모듈 ↔ `supabase/functions/get-player` (선수 상세)

## 주요 의존성

- `get` ^4.6.6 — 상태관리 / 라우팅 / DI
- `supabase_flutter` ^2.5.0 — Edge Function 호출 / 세션 JWT 자동 첨부
- `flutter_dotenv` ^5.1.0 — `.env` 환경변수 로드
- `cached_network_image` ^3.3.1 — 대회 로고 / 국기 캐시
- `url_launcher` ^6.2.6 — 대회 상세 외부 브라우저 오픈

## 라우트 상수 (Routes)

```dart
abstract class Routes {
  static const APP = '/app';
  static const NEWS = '/news';
  static const MATCH = '/match';
  static const MATCH_DETAIL = '/match/detail';
  static const MATCH_PARTICIPANTS = '/match/participants';  // TASK-006
  static const PLAYER = '/player';
  static const PLAYER_DETAIL = '/player/detail';
  static const MY_INFO = '/my-info';
  static const LOGIN = '/login';
  static const SIGN_UP = '/sign-up';
}
```

## Stitch 매핑 (rally 프로젝트 ID: 307006344264476289)

| View | Stitch 화면명 | screenId |
|------|---------------|----------|
| `match_view.dart` | 국제 대회 리스트 (매거진) | `225c4429594e4cb3835b154cbc861919` |
| `tournament_detail_view.dart` | 대회 상세 - 경기 리스트 | TBD |
| `tournament_participants_view.dart` | 대회 상세 - 참가 선수 (TASK-006) | TBD |
| `player_view.dart` | 선수 리스트 (매거진) | `eeae55cab3614d408743636d325e3b88` |
| `player_detail_view.dart` | 선수 상세 | TBD |
| `my_info_view.dart` | 내 정보 (매거진) | `8329646c315c48fdb5bfa15f9a643418` |
| `login_view.dart` | 로그인 (Kinetic Court) | `a7cf71e767ad4610a93373028a9c3ab0` |
| `sign_up_view.dart` | 회원가입 - 이메일 인증 | `3616350c62da4e95906ab4d458eb7ebc` |
