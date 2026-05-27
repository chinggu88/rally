# TASKS

> 율곡(Yulgok)이 생성한 태스크 문서. team-lead agent가 이 문서를 읽어 서브 agent들에게 작업을 분배한다.

---

## TASK-001: 내 정보 (비로그인 상태) 화면

- **상태**: `completed`
- **개발 유형**: 유지보수
- **생성일**: 2026-05-26
- **설명**: 기존 `MyInfoView`를 비로그인 상태 UI로 교체하여, 로그인 버튼을 통해 로그인 화면으로 이동할 수 있는 진입 화면으로 만든다.

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 유지보수 |
| 판단 근거 | `lib/app/modules/my_info/` 모듈이 이미 존재하며, 기획서가 "내정보 바텀네비게이션 화면 연동"으로 기존 화면 교체를 요청 |
| 영향 범위 | `lib/app/modules/my_info/` (View, Controller), 바텀네비를 호스팅하는 `lib/app/modules/app/` 모듈 |

---

### 파일 목록

#### 신규 생성 파일
- 없음 (기존 모듈 수정)

#### 수정 파일
- `lib/app/modules/my_info/views/my_info_view.dart` — 비로그인 상태 UI 구현
- `lib/app/modules/my_info/controllers/my_info_controller.dart` — 로그인 화면 이동 메서드 추가

---

### API Agent 작업

#### 생성 파일
- 없음

#### API 정보
| Method | Endpoint | 설명 |
|--------|----------|------|
| - | - | 본 태스크는 API 연동 없음 (기획서 명시) |

> API 연동은 추후 별도 태스크로 처리한다.

---

### Controller Agent 작업

#### 생성 파일
- 없음 (기존 `my_info_controller.dart` 수정)

#### 기능 정의
- [x] `goToLogin()` 메서드 추가 — `Get.toNamed(Routes.LOGIN)` 호출
- [x] 로그인 상태 관리 변수 (`isLoggedIn`) — 현재는 항상 `false` (추후 GetStorage 연동)
- [x] `onInit`에서 로그인 상태 확인 후 화면 분기 로직 자리 마련 (TODO 주석)

#### 의존성
- `lib/app/routes/app_routes.dart`에 `LOGIN` 라우트 상수 추가 필요 (TASK-002에서 정의)

---

### UI Agent 작업

#### 생성 파일
- 없음 (기존 `my_info_view.dart` 교체)

#### UI 구성
- **화면 유형**: 진입/안내 화면 (비로그인 상태)
- **레이아웃**: 중앙 정렬, 상단 안내 텍스트 + 하단 로그인 버튼
- **주요 위젯**: `Scaffold`, `AppBar`, 안내 문구 Text, `ElevatedButton`(로그인 버튼)
- **상태 표시**: 별도 로딩/에러 상태 없음 (정적 UI)

#### Stitch 화면 매핑 (필수)
**rally 프로젝트는 항상 Stitch 프로젝트 `307006344264476289`를 사용한다.**

| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `my_info_view.dart` | 내 정보 (매거진) | `8329646c315c48fdb5bfa15f9a643418` | `projects/307006344264476289/screens/8329646c315c48fdb5bfa15f9a643418` |

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| `my_info_view.dart` | 없음 | docs/task/ 폴더에 이미지 파일 없음 |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent 수정 파일: `lib/app/modules/my_info/controllers/my_info_controller.dart`
- Route 상수: `Routes.LOGIN` (TASK-002에서 추가)

---

### QA 체크리스트

#### 기능 테스트
- [ ] 비로그인 상태에서 바텀네비 "내정보" 탭 진입 시 안내 화면 정상 표시
- [ ] 로그인 버튼 탭 시 로그인 화면(`/login`)으로 이동
- [ ] 뒤로 가기 동작 시 바텀네비 이전 탭으로 정상 복귀

#### 예외 처리 / 엣지 케이스
- [ ] 화면 진입/이탈 시 상태 초기화 확인 (`onInit`/`onClose`)
- [ ] 빠른 더블 탭 시 로그인 화면 중복 push 방지

#### UI/UX 테스트
- [ ] 다양한 화면 크기에서 레이아웃 정상 표시 (ScreenUtil)
- [ ] Stitch 디자인과 시각적 일치 (색상/타이포/여백)
- [ ] 다크/라이트 테마 적용 시 가독성 확인

#### 유지보수 전용
- [ ] 수정 전 기존 `MyInfoView` 라우팅 회귀 테스트 (`Routes.MY_INFO` 정상 동작)
- [ ] 바텀네비를 호스팅하는 `AppView`에서 탭 전환 정상 동작
- [ ] 연관 화면(news, match, player) 정상 동작 확인

---

## TASK-002: 로그인 화면

- **상태**: `completed`
- **개발 유형**: 신규개발
- **생성일**: 2026-05-26
- **설명**: 로그인 화면(`login`)을 신규 모듈로 추가한다. 회원가입 버튼 탭 시 회원가입(이메일 인증) 화면으로 이동한다. API 연동은 본 태스크에서 제외.

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | `lib/app/modules/login/` 모듈이 존재하지 않음 |
| 영향 범위 | 없음 (신규 모듈) + `app_routes.dart` / `app_pages.dart` 라우트 등록 |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/modules/login/controllers/login_controller.dart`
- `lib/app/modules/login/bindings/login_binding.dart`
- `lib/app/modules/login/views/login_view.dart`

#### 수정 파일
- `lib/app/routes/app_routes.dart` — `LOGIN = '/login'` 상수 추가
- `lib/app/routes/app_pages.dart` — `GetPage(name: Routes.LOGIN, ...)` 등록

---

### API Agent 작업

#### 생성 파일
- 없음 (본 태스크는 API 연동 없음 — 기획서 명시)

#### API 정보
| Method | Endpoint | 설명 |
|--------|----------|------|
| - | - | UI만 구현. 인증 API는 추후 별도 태스크로 처리 |

---

### Controller Agent 작업

#### 생성 파일
- `lib/app/modules/login/controllers/login_controller.dart`
- `lib/app/modules/login/bindings/login_binding.dart`

#### 기능 정의
- [x] 이메일 입력 `TextEditingController` 관리 (`emailController`)
- [x] 비밀번호 입력 `TextEditingController` 관리 (`passwordController`)
- [x] 이메일/비밀번호 유효성 표시용 reactive 변수 (`isEmailValid`, `isPasswordValid`)
- [x] `goToSignUp()` 메서드 — `Get.toNamed(Routes.SIGN_UP)` 호출
- [x] `login()` 메서드 — 현재는 placeholder (TODO 주석으로 API 연동 자리 표시)
- [x] `onClose()`에서 `TextEditingController` 안전 dispose
- [x] isLoading 상태 관리 (API 연동 시 사용)

#### 의존성
- 없음 (API 연동 없음)

---

### UI Agent 작업

#### 생성 파일
- `lib/app/modules/login/views/login_view.dart`

#### UI 구성
- **화면 유형**: 입력 폼 화면
- **레이아웃**: 상단 로고/타이틀 → 이메일/비밀번호 입력 필드 → 로그인 버튼 → 하단 "회원가입" 텍스트 버튼
- **주요 위젯**: `Scaffold`, `TextField`(이메일/비밀번호), `ElevatedButton`(로그인), `TextButton`(회원가입 이동)
- **상태 표시**: 로딩 상태(`isLoading`), 입력 유효성 표시

#### Stitch 화면 매핑 (필수)
**rally 프로젝트는 항상 Stitch 프로젝트 `307006344264476289`를 사용한다.**

| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `login_view.dart` | 로그인 (Kinetic Court) | `a7cf71e767ad4610a93373028a9c3ab0` | `projects/307006344264476289/screens/a7cf71e767ad4610a93373028a9c3ab0` |

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| `login_view.dart` | 없음 | docs/task/ 폴더에 이미지 파일 없음 |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent 생성 파일: `lib/app/modules/login/controllers/login_controller.dart`
- Route 상수: `Routes.SIGN_UP` (TASK-003에서 추가)

---

### QA 체크리스트

#### 기능 테스트
- [ ] 내 정보(비로그인) 화면에서 로그인 버튼 → 로그인 화면 진입
- [ ] 이메일/비밀번호 입력 정상 동작
- [ ] 회원가입 텍스트 버튼 탭 → 회원가입 이메일 인증 화면으로 이동
- [ ] 로그인 버튼 탭 시 (현재는 placeholder) 무동작 또는 토스트 표시

#### 예외 처리 / 엣지 케이스
- [ ] 빈 입력값에서 로그인 버튼 동작 처리
- [ ] 화면 진입/이탈 시 상태 초기화 확인 (`onInit`/`onClose`, controller dispose)
- [ ] 키보드 표시 시 입력 필드가 가려지지 않음 (`resizeToAvoidBottomInset`)
- [ ] 빠른 더블 탭 시 회원가입 화면 중복 push 방지

#### UI/UX 테스트
- [ ] 다양한 화면 크기에서 레이아웃 정상 표시 (ScreenUtil)
- [ ] Stitch 디자인과 시각적 일치 (색상/타이포/여백)
- [ ] 입력 필드 focus 이동 (이메일 → 비밀번호) 자연스러움
- [ ] 비밀번호 가리기/보이기 토글 정상 동작 (디자인에 포함된 경우)

---

## TASK-003: 회원가입 - 이메일 인증 화면

- **상태**: `completed`
- **개발 유형**: 신규개발
- **생성일**: 2026-05-26
- **설명**: 회원가입 이메일 인증 화면(`sign_up`)을 신규 모듈로 추가한다. 로그인 화면에서 진입 가능하며, 본 태스크에서는 이메일 인증 단계 1개 화면만 구현한다(기획서 확인). API 연동 제외.

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | `lib/app/modules/sign_up/` 모듈이 존재하지 않음 |
| 영향 범위 | 없음 (신규 모듈) + `app_routes.dart` / `app_pages.dart` 라우트 등록 |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/modules/sign_up/controllers/sign_up_controller.dart`
- `lib/app/modules/sign_up/bindings/sign_up_binding.dart`
- `lib/app/modules/sign_up/views/sign_up_view.dart`

#### 수정 파일
- `lib/app/routes/app_routes.dart` — `SIGN_UP = '/sign-up'` 상수 추가
- `lib/app/routes/app_pages.dart` — `GetPage(name: Routes.SIGN_UP, ...)` 등록

---

### API Agent 작업

#### 생성 파일
- 없음 (본 태스크는 API 연동 없음 — 기획서 명시)

#### API 정보
| Method | Endpoint | 설명 |
|--------|----------|------|
| - | - | UI만 구현. 이메일 인증 API는 추후 별도 태스크로 처리 |

---

### Controller Agent 작업

#### 생성 파일
- `lib/app/modules/sign_up/controllers/sign_up_controller.dart`
- `lib/app/modules/sign_up/bindings/sign_up_binding.dart`

#### 기능 정의
- [x] 이메일 입력 `TextEditingController` 관리 (`emailController`)
- [x] 이메일 형식 유효성 검사 reactive 변수 (`isEmailValid`)
- [x] 인증번호 입력 `TextEditingController` 관리 (`codeController`) — Stitch 디자인에 포함된 경우
- [x] `requestVerification()` 메서드 — 현재는 placeholder (TODO 주석)
- [x] `verifyCode()` 메서드 — 현재는 placeholder (TODO 주석)
- [x] 인증 코드 타이머 reactive 변수 (`remainingSeconds`) — Stitch 디자인에 포함된 경우
- [x] `onClose()`에서 `TextEditingController` / `Timer` 안전 dispose
- [x] isLoading 상태 관리

#### 의존성
- 없음 (API 연동 없음)

---

### UI Agent 작업

#### 생성 파일
- `lib/app/modules/sign_up/views/sign_up_view.dart`

#### UI 구성
- **화면 유형**: 입력 폼 화면 (인증 단계)
- **레이아웃**: 상단 헤더 → 이메일 입력 → 인증번호 발송 버튼 → 인증번호 입력 + 타이머 → 다음 버튼
- **주요 위젯**: `Scaffold`, `AppBar`(뒤로가기), `TextField`(이메일/코드), `ElevatedButton`(인증 요청/다음)
- **상태 표시**: 로딩 상태(`isLoading`), 이메일 유효성, 인증 타이머

#### Stitch 화면 매핑 (필수)
**rally 프로젝트는 항상 Stitch 프로젝트 `307006344264476289`를 사용한다.**

| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `sign_up_view.dart` | 회원가입 - 이메일 인증 (Kinetic Court) | `3616350c62da4e95906ab4d458eb7ebc` | `projects/307006344264476289/screens/3616350c62da4e95906ab4d458eb7ebc` |

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| `sign_up_view.dart` | 없음 | docs/task/ 폴더에 이미지 파일 없음 |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent 생성 파일: `lib/app/modules/sign_up/controllers/sign_up_controller.dart`
- 진입 경로: 로그인 화면(TASK-002)의 "회원가입" 버튼

---

### QA 체크리스트

#### 기능 테스트
- [ ] 로그인 화면 → "회원가입" 탭 → 이메일 인증 화면 진입
- [ ] 이메일 입력 정상 동작 및 형식 검증 표시
- [ ] 인증번호 발송 버튼 탭 (placeholder 동작)
- [ ] 인증번호 입력 정상 동작
- [ ] 뒤로 가기 → 로그인 화면 복귀

#### 예외 처리 / 엣지 케이스
- [ ] 잘못된 이메일 형식 입력 시 안내 표시
- [ ] 화면 진입/이탈 시 상태 초기화 확인 (`onInit`/`onClose`, controller/Timer dispose)
- [ ] 키보드 표시 시 입력 필드가 가려지지 않음
- [ ] 인증 코드 타이머 만료/재발송 시 상태 정상 처리 (디자인 포함 시)
- [ ] 빠른 더블 탭 시 중복 요청 방지

#### UI/UX 테스트
- [ ] 다양한 화면 크기에서 레이아웃 정상 표시 (ScreenUtil)
- [ ] Stitch 디자인과 시각적 일치 (색상/타이포/여백)
- [ ] 입력 필드 focus 이동 자연스러움
- [ ] 특수문자/한글 이메일 입력 처리

---

## TASK-004: 경기 화면 - 국제 대회 리스트 (매거진)

- **상태**: `completed`
- **개발 유형**: 유지보수 + 신규개발(데이터 레이어/Supabase 초기화)
- **생성일**: 2026-05-27
- **완료일**: 2026-05-27
- **설명**: 바텀네비 "경기" 탭 화면(`lib/app/modules/match/`)을 placeholder에서 국제 대회 리스트(매거진) 화면으로 교체한다. Supabase Edge Function `get-tournaments`를 호출해 연도별 대회 목록을 매거진 스타일로 표시한다. 본 태스크에서 Supabase Flutter SDK 초기화 및 데이터 레이어(`lib/app/data/`)를 신규로 도입한다.

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 유지보수(match 모듈 교체) + 신규개발(Supabase 초기화 / 데이터 레이어 신규) |
| 판단 근거 | `lib/app/modules/match/`는 이미 존재하지만 placeholder. `lib/app/data/` 폴더와 Supabase 클라이언트 초기화는 프로젝트 전체에서 처음 도입 |
| 영향 범위 | `lib/app/modules/match/` (View/Controller/Binding), `lib/main.dart` (Supabase 초기화), `pubspec.yaml`(`supabase_flutter` 의존성), `.env` (URL/anon key), `lib/app/data/` 신규 |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/data/models/tournament_response.dart` — 대회 단일 항목 모델
- `lib/app/data/models/get_tournaments_response.dart` — `{ year, count, tournaments }` 래퍼 모델
- `lib/app/data/repositories/tournament_repository.dart` — `get-tournaments` Edge Function 호출 레포지토리
- `lib/services/supabase_service.dart` — Supabase 클라이언트 GetxService 래퍼 (초기화 + functions 호출 헬퍼)

#### 수정 파일
- `pubspec.yaml` — `supabase_flutter` 의존성 추가, `flutter_dotenv`, `cached_network_image` 추가
- `lib/main.dart` — `WidgetsFlutterBinding.ensureInitialized()` / `dotenv.load()` / `Supabase.initialize()` / `Get.putAsync(SupabaseService)` 등록
- `.env` — `SUPABASE_URL`, `SUPABASE_ANON_KEY` 추가 (실제 키 값은 사용자가 채움)
- `lib/app/modules/match/views/match_view.dart` — 매거진 스타일 대회 리스트 UI로 전체 교체
- `lib/app/modules/match/controllers/match_controller.dart` — 대회 목록 fetch, 로딩/에러/연도 필터 상태 관리
- `lib/app/modules/match/bindings/match_binding.dart` — `TournamentRepository` lazyPut 주입

---

### API Agent 작업

#### 생성 파일
- `lib/app/data/models/tournament_response.dart`
- `lib/app/data/models/get_tournaments_response.dart`
- `lib/app/data/repositories/tournament_repository.dart`
- `lib/services/supabase_service.dart`

#### API 정보
| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `functions/v1/get-tournaments?year={YYYY}` | BWF 국제 대회 연도별 목록 조회 (year 미지정 시 현재 연도) |

#### 요청 파라미터
| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `year` | int (query) | 선택 | 2000–2100. 미지정 시 현재 연도 |

#### 응답 스펙 (200)
```json
{
  "year": 2026,
  "count": 32,
  "tournaments": [
    {
      "tournament_id": "string",
      "name": "string",
      "tour_level": "string",
      "start_date": "YYYY-MM-DD",
      "end_date": "YYYY-MM-DD",
      "date_label": "string",
      "country": "string",
      "location": "string",
      "prize_money_usd": 0,
      "detail_url": "string",
      "flag_url": "string",
      "logo_url": "string",
      "cat_logo_url": "string",
      "status": "string",
      "has_live_scores": false
    }
  ]
}
```

#### 모델 정의
- `TournamentResponse` — 위 단일 tournament 객체의 모든 필드를 `String?` / `int?` / `bool?`로 mapping (docs/api/MODEL_GUIDE.md Response 컨벤션 준수: private 필드 + getter/setter + fromJson/toJson)
- `GetTournamentsResponse` — `int? year`, `int? count`, `List<TournamentResponse>? tournaments`

#### 레포지토리 정의
- `TournamentRepository.getTournaments({int? year}) → Future<GetTournamentsResponse>`
  - 내부적으로 `Supabase.instance.client.functions.invoke('get-tournaments', queryParameters: { 'year': year?.toString() })` 호출
  - 실패(non-2xx)일 때 `Exception('get-tournaments failed: ${message}')` throw

#### Supabase 초기화
- `lib/services/supabase_service.dart`는 `GetxService`를 상속하고 `static client` 접근자 제공
- `.env`의 `SUPABASE_URL`, `SUPABASE_ANON_KEY`를 `flutter_dotenv`로 로드
- `main.dart`에서 `await Supabase.initialize(...)` 후 `Get.put(SupabaseService())`

#### 의존성
- `supabase_flutter: ^2.5.0` (또는 최신)
- `flutter_dotenv: ^5.1.0`
- `cached_network_image: ^3.3.1` (flag/logo 이미지 표시용 — UI Agent에서도 사용)

---

### Controller Agent 작업

#### 생성 파일
- 없음 (기존 `match_controller.dart` / `match_binding.dart` 수정)

#### 기능 정의
- [x] `tournaments` — `RxList<TournamentResponse>` 대회 목록
- [x] `isLoading` — `RxBool` 로딩 상태
- [x] `errorMessage` — `RxnString` 에러 메시지 (null이면 정상)
- [x] `selectedYear` — `RxInt` 현재 선택 연도 (기본값: `DateTime.now().year`)
- [x] `onInit()` — 진입 시 `fetchTournaments()` 1회 호출
- [x] `fetchTournaments({int? year})` — `TournamentRepository.getTournaments` 호출 → `tournaments`/`year` 갱신, 예외 시 `errorMessage` 세팅
- [x] `refreshTournaments()` — Pull-to-refresh / 재시도 버튼용 (현재 `selectedYear`로 재호출)
- [x] `changeYear(int year)` — 연도 변경 시 `selectedYear` 갱신 + `fetchTournaments` 재호출
- [x] `openTournamentDetail(TournamentResponse t)` — `detail_url`이 있으면 `url_launcher`로 외부 브라우저 오픈 (또는 추후 상세 화면 라우팅 자리 TODO 주석)
- [x] `MatchBinding.dependencies()` — `Get.lazyPut(() => TournamentRepository())` + `Get.lazyPut(() => MatchController())`

#### 의존성
- API Agent 생성 파일: `tournament_repository.dart`, `tournament_response.dart`, `get_tournaments_response.dart`

---

### UI Agent 작업

#### 생성 파일
- 없음 (기존 `match_view.dart` 전체 교체)

#### UI 구성
- **화면 유형**: 매거진 스타일 리스트 화면
- **레이아웃**:
  1. AppBar — "Kinetic Court" 로고 텍스트 + 검색 아이콘 (기존 `my_info_view.dart` AppBar 톤 유지)
  2. 헤더 섹션 — "국제 대회" 타이틀 + 선택 연도 표시 + 연도 변경 컨트롤(좌우 화살표 또는 칩)
  3. 상태 분기:
     - 로딩: 중앙 `CircularProgressIndicator`
     - 에러: 메시지 + "다시 시도" 버튼 → `controller.refreshTournaments()`
     - 빈 결과: "해당 연도에 등록된 대회가 없습니다" 안내
     - 정상: `ListView` 또는 `Column` (Pull-to-refresh: `RefreshIndicator`)
  4. 대회 카드 (1개 item):
     - 좌측 상단 라벨 라인: `tour_level` 뱃지 + `country` 국기(`flag_url`) + 국가명
     - 메인 타이틀: `name` (2줄 ellipsis)
     - 서브: `date_label` (or `start_date ~ end_date`) · `location`
     - 우측: `logo_url` 썸네일 (대회 로고)
     - 하단 메타: `prize_money_usd`(있을 때만 `$1,200,000` 포맷) · `status` 뱃지 · `has_live_scores`가 true면 "LIVE" 표시
     - 탭 → `controller.openTournamentDetail(t)`
- **주요 위젯**: `Scaffold`, `AppBar`, `RefreshIndicator`, `ListView.separated`, `Obx`, `CachedNetworkImage`, `InkWell`, `Container`(라운드 카드)
- **상태 표시**: `Obx`로 `isLoading` / `errorMessage` / `tournaments`를 반응형 바인딩

#### Stitch 화면 매핑 (필수)
**rally 프로젝트는 항상 Stitch 프로젝트 `307006344264476289`를 사용한다.**

| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `match_view.dart` | 국제 대회 리스트 (매거진) | `225c4429594e4cb3835b154cbc861919` | `projects/307006344264476289/screens/225c4429594e4cb3835b154cbc861919` |

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| `match_view.dart` | 없음 | docs/task/ 폴더에 이미지 파일 없음 (Stitch 스크린샷 사용) |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent 수정 파일: `lib/app/modules/match/controllers/match_controller.dart`
- API Agent 생성 모델: `TournamentResponse`, `GetTournamentsResponse`
- Theme 토큰: `lib/theme/app_colors.dart` (`primaryContainer` = 라임 옐로우 `#C3F400` 액센트 컬러로 활용)
- `cached_network_image` 패키지

---

### QA 체크리스트

#### 기능 테스트
- [ ] 바텀네비 "경기" 탭 진입 시 자동으로 대회 리스트 로딩
- [ ] 정상 응답 시 매거진 카드 리스트가 `start_date` 오름차순으로 표시
- [ ] Pull-to-refresh 동작 정상
- [ ] 연도 변경 컨트롤로 다른 연도(예: 2025) 조회 시 리스트 갱신
- [ ] 대회 카드 탭 시 `detail_url` 외부 브라우저로 오픈 (또는 placeholder 토스트)
- [ ] `flag_url`/`logo_url` 이미지 정상 로드 및 캐시 동작
- [ ] `has_live_scores`가 true인 카드에 "LIVE" 뱃지 표시

#### 예외 처리 / 엣지 케이스
- [ ] 네트워크 오류 시 에러 메시지 + "다시 시도" 버튼 동작
- [ ] 빈 결과(`count: 0`) 시 안내 문구 표시
- [ ] 잘못된 연도(2099 등 데이터 없는 연도) 조회 시 정상 빈 상태 처리
- [ ] `prize_money_usd`가 null 또는 0인 경우 표시 생략 또는 "—" 처리
- [ ] `logo_url`/`flag_url`이 null/잘못된 URL일 때 placeholder 이미지 표시
- [ ] Supabase 초기화 실패(env key 누락) 시 명시적 에러 로그
- [ ] 빠른 더블 탭 시 중복 fetch / 외부 링크 중복 오픈 방지

#### UI/UX 테스트
- [ ] 다양한 화면 크기에서 카드 레이아웃 정상 (Overflow 없음)
- [ ] Stitch 디자인과 시각적 일치 (색상/타이포/여백/카드 라운드)
- [ ] 다크 테마(현재 기본)에서 가독성 / 라임 옐로우 액센트 적용 일치
- [ ] 긴 대회 이름 / 긴 location 텍스트 ellipsis 처리
- [ ] 스크롤 성능 (이미지 캐시 적용 후 60fps 근접)

#### 유지보수 / 신규 도입 전용
- [ ] 기존 `MatchView` 라우팅(`Routes.MATCH`) 회귀 — 바텀네비 탭 전환 정상
- [ ] 다른 탭(news, player, my_info, login, sign_up) 정상 동작 (Supabase 초기화 영향 없음)
- [ ] `pubspec.yaml` 변경 후 `flutter pub get` 정상
- [ ] `.env` 누락 시 명확한 가이드 메시지 (FlutterError 또는 로그)
- [ ] `architecture.md`를 신규 구조(`lib/app/data/`, `lib/services/`)에 맞춰 `architecture-update` agent로 갱신

---

## TASK-005: 선수 화면 - BWF 랭킹 선수 리스트 (매거진)

- **상태**: `completed`
- **개발 유형**: 유지보수 (placeholder 교체)
- **생성일**: 2026-05-27
- **완료일**: 2026-05-27
- **설명**: 바텀네비 "선수" 탭 화면(`lib/app/modules/player/`)을 placeholder에서 BWF 랭킹 선수 리스트(매거진) 화면으로 교체한다. Supabase Edge Function `get-players`를 호출해 종목별(MS/WS/MD/WD/XD) 선수 랭킹을 매거진 스타일로 표시한다. TASK-004에서 도입한 데이터 레이어(`lib/app/data/`)와 `SupabaseService`를 재사용한다.

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 유지보수 (player 모듈 placeholder 교체) |
| 판단 근거 | `lib/app/modules/player/`는 이미 존재(placeholder). Supabase 초기화/데이터 레이어는 TASK-004에서 도입 완료되어 재사용 |
| 영향 범위 | `lib/app/modules/player/` (View/Controller/Binding), `lib/app/data/models/`, `lib/app/data/repositories/` (모델/레포 신규 추가) |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/data/models/player_response.dart` — 선수 단일 항목 모델 (`rank`, `player_name`, `country_code`)
- `lib/app/data/models/get_players_response.dart` — `{ category, count, players }` 래퍼 모델
- `lib/app/data/repositories/player_repository.dart` — `get-players` Edge Function 호출 레포지토리

#### 수정 파일
- `lib/app/modules/player/views/player_view.dart` — 매거진 스타일 선수 리스트 UI로 전체 교체
- `lib/app/modules/player/controllers/player_controller.dart` — 선수 목록 fetch, 로딩/에러/카테고리 필터 상태 관리
- `lib/app/modules/player/bindings/player_binding.dart` — `PlayerRepository` lazyPut 주입

---

### API Agent 작업

#### 생성 파일
- `lib/app/data/models/player_response.dart`
- `lib/app/data/models/get_players_response.dart`
- `lib/app/data/repositories/player_repository.dart`

#### API 정보
| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `functions/v1/get-players?category={MS|WS|MD|WD|XD}` | BWF 종목별 랭킹 선수 목록 조회 (category 미지정 시 `MS`) |

#### 요청 파라미터
| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `category` | string (query) | 선택 | `MS`(남단), `WS`(여단), `MD`(남복), `WD`(여복), `XD`(혼복) 중 하나. 미지정 시 `MS` |

#### 응답 스펙 (200)
```json
{
  "category": "MS",
  "count": 100,
  "players": [
    {
      "rank": 1,
      "player_name": "string",
      "country_code": "string"
    }
  ]
}
```

#### 모델 정의
- `PlayerResponse` — 위 단일 player 객체의 모든 필드를 `int?`(rank) / `String?`(player_name, country_code)로 mapping (docs/api/MODEL_GUIDE.md Response 컨벤션 준수: private 필드 + getter/setter + fromJson/toJson). `TournamentResponse`와 동일한 스타일 유지.
- `GetPlayersResponse` — `String? category`, `int? count`, `List<PlayerResponse>? players`. `GetTournamentsResponse`와 동일 패턴.

#### 레포지토리 정의
- `PlayerRepository.getPlayers({String? category}) → Future<GetPlayersResponse>`
  - 내부적으로 `Supabase.instance.client.functions.invoke('get-players', queryParameters: { 'category': category })` 호출 (`TournamentRepository`와 동일 패턴)
  - 실패(non-2xx)일 때 `Exception('get-players failed: ${message}')` throw

#### 의존성
- TASK-004에서 도입한 `SupabaseService` 및 `lib/app/data/` 구조 재사용 (`supabase_flutter` 의존성 추가 작업 없음)

---

### Controller Agent 작업

#### 생성 파일
- 없음 (기존 `player_controller.dart` / `player_binding.dart` 수정)

#### 기능 정의
- [x] `players` — `RxList<PlayerResponse>` 선수 목록
- [x] `isLoading` — `RxBool` 로딩 상태
- [x] `errorMessage` — `RxnString` 에러 메시지 (null이면 정상)
- [x] `selectedCategory` — `RxString` 현재 선택 카테고리 (기본값: `'MS'`)
- [x] `categories` — 정적 리스트 `['MS', 'WS', 'MD', 'WD', 'XD']` + 한국어 라벨 매핑 헬퍼 (`'MS' → '남자 단식'`, `'WS' → '여자 단식'`, `'MD' → '남자 복식'`, `'WD' → '여자 복식'`, `'XD' → '혼합 복식'`)
- [x] `onInit()` — 진입 시 `fetchPlayers()` 1회 호출
- [x] `fetchPlayers({String? category})` — `PlayerRepository.getPlayers` 호출 → `players`/`selectedCategory` 갱신, 예외 시 `errorMessage` 세팅
- [x] `refreshPlayers()` — Pull-to-refresh / 재시도 버튼용 (현재 `selectedCategory`로 재호출)
- [x] `changeCategory(String category)` — 카테고리 변경 시 `selectedCategory` 갱신 + `fetchPlayers` 재호출 (동일 카테고리 재선택 시 no-op)
- [x] `PlayerBinding.dependencies()` — `Get.lazyPut(() => PlayerRepository())` + `Get.lazyPut(() => PlayerController())`

#### 의존성
- API Agent 생성 파일: `player_repository.dart`, `player_response.dart`, `get_players_response.dart`

---

### UI Agent 작업

#### 생성 파일
- 없음 (기존 `player_view.dart` 전체 교체)

#### UI 구성
- **화면 유형**: 매거진 스타일 랭킹 리스트 화면
- **레이아웃**:
  1. AppBar — "Kinetic Court" 로고 텍스트 + 검색 아이콘 (기존 `match_view.dart` AppBar 톤 유지)
  2. 헤더 섹션 — "선수 랭킹" 타이틀 + 카테고리 칩 그룹(`MS/WS/MD/WD/XD` 5개 가로 스크롤 가능 ChoiceChip)
  3. 상태 분기:
     - 로딩: 중앙 `CircularProgressIndicator`
     - 에러: 메시지 + "다시 시도" 버튼 → `controller.refreshPlayers()`
     - 빈 결과: "해당 종목 랭킹 데이터가 없습니다" 안내
     - 정상: `ListView.separated` (Pull-to-refresh: `RefreshIndicator`)
  4. 선수 카드 (1개 item, 매거진 카드 스타일):
     - 좌측: 랭킹 숫자 큰 타이포 (`#1`, `#2` 형식, 라임 옐로우 액센트)
     - 중앙: `player_name` (선수명, 큰 폰트) + `country_code`(국가 3자 코드, 작은 sub 라벨)
     - 우측: 국가 표시 (국가코드 텍스트 또는 placeholder 국기 아이콘 — `flag_url`이 응답에 없으므로 `country_code` 텍스트 우선)
     - 탭 → placeholder (선수 상세는 추후 별도 태스크. TODO 주석으로 `Get.toNamed(Routes.PLAYER_DETAIL)` 자리 표시)
- **주요 위젯**: `Scaffold`, `AppBar`, `RefreshIndicator`, `ListView.separated`, `Obx`, `ChoiceChip` (or 커스텀 Container 칩), `InkWell`, `Container`(라운드 카드)
- **상태 표시**: `Obx`로 `isLoading` / `errorMessage` / `players` / `selectedCategory`를 반응형 바인딩

#### Stitch 화면 매핑 (필수)
**rally 프로젝트는 항상 Stitch 프로젝트 `307006344264476289`를 사용한다.**

| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `player_view.dart` | 선수 리스트 (매거진) | `eeae55cab3614d408743636d325e3b88` | `projects/307006344264476289/screens/eeae55cab3614d408743636d325e3b88` |

> 참고: 선수 상세 화면(`projects/307006344264476289/screens/b3ae5f6699f448e5bae6703091c35026`, "선수 프로필: Shi Yu Qi (매거진)")은 추후 별도 태스크로 처리.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| `player_view.dart` | 없음 | docs/task/ 폴더에 이미지 파일 없음 (Stitch 스크린샷 사용) |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent 수정 파일: `lib/app/modules/player/controllers/player_controller.dart`
- API Agent 생성 모델: `PlayerResponse`, `GetPlayersResponse`
- Theme 토큰: `lib/theme/app_colors.dart` (라임 옐로우 `#C3F400` 액센트를 랭킹 숫자/선택 칩에 활용)
- `cached_network_image` 패키지 (응답에 이미지 URL 없지만 향후 확장 대비 import 가능)

---

### QA 체크리스트

#### 기능 테스트
- [ ] 바텀네비 "선수" 탭 진입 시 자동으로 `MS`(남자 단식) 랭킹 로딩
- [ ] 정상 응답 시 `rank` 오름차순으로 매거진 카드 리스트 표시
- [ ] Pull-to-refresh 동작 정상
- [ ] 카테고리 칩(`MS/WS/MD/WD/XD`) 탭 시 해당 종목 랭킹으로 리스트 갱신
- [ ] 동일 카테고리 재탭 시 중복 호출 없음 (또는 명시적 refresh)
- [ ] 선수 카드 탭 시 placeholder 동작 (현재는 무동작 또는 토스트)

#### 예외 처리 / 엣지 케이스
- [ ] 네트워크 오류 시 에러 메시지 + "다시 시도" 버튼 동작
- [ ] 빈 결과(`count: 0`) 시 안내 문구 표시
- [ ] 잘못된 카테고리(서버 400 응답) 시 에러 메시지 표시 — 클라이언트에서도 5개 카테고리만 허용
- [ ] `player_name` / `country_code`가 null인 경우 안전한 fallback 표시 (`'—'`)
- [ ] 빠른 더블 탭 시 중복 fetch 방지
- [ ] 카테고리 전환 중 이전 응답이 늦게 도착하는 race condition 방지 (요청 토큰 또는 단일 inflight 보장)

#### UI/UX 테스트
- [ ] 다양한 화면 크기에서 카드 레이아웃 정상 (Overflow 없음)
- [ ] Stitch 디자인과 시각적 일치 (색상/타이포/여백/카드 라운드)
- [ ] 다크 테마(현재 기본)에서 가독성 / 라임 옐로우 액센트 적용 일치
- [ ] 긴 선수명(국제 선수 풀네임) ellipsis 처리
- [ ] 카테고리 칩 가로 스크롤 자연스러움 / 선택 상태 시각적 명확
- [ ] 스크롤 성능 (100명 리스트도 60fps 근접)

#### 유지보수 / 회귀
- [ ] 기존 `PlayerView` 라우팅(`Routes.PLAYER`) 회귀 — 바텀네비 탭 전환 정상
- [ ] 다른 탭(news, match, my_info, login, sign_up) 정상 동작 (PlayerRepository 추가 영향 없음)
- [ ] TASK-004에서 추가된 `SupabaseService` 및 `lib/app/data/` 구조 재사용 확인 (`supabase_flutter` 의존성 재설치 불필요)
- [ ] `architecture.md`에 신규 모델/레포 반영 (`architecture-update` agent)

---

## 비고

- **API 연동 없음 (기획서 명시)**: TASK-001~003은 모두 UI/네비게이션만 구현했다. TASK-004부터 Supabase Edge Function 연동을 본격 도입한다.
- **Supabase 초기화 최초 도입**: TASK-004에서 `supabase_flutter` 패키지와 `lib/app/data/`, `lib/services/` 구조를 신규로 만든다. 이후 태스크(TASK-005 포함)는 본 구조를 재사용한다.
- **architecture.md 불일치 주의**: `docs/architecture.md`는 다른 프로젝트(testuram)의 구조로 보인다. 본 태스크의 파일 경로는 실제 `lib/app/` 구조(`app`, `match`, `my_info`, `news`, `player`, `login`, `sign_up` 모듈)를 기반으로 작성되었다. 작업 완료 후 `architecture-update` agent로 동기화 권장.
- **Stitch 프로젝트**: 항상 `307006344264476289` (셔틀콕 뉴스 매거진) 사용.
- **선수 상세 화면**: Stitch에 별도 화면(`b3ae5f6699f448e5bae6703091c35026`, "선수 프로필: Shi Yu Qi")이 있으나 본 태스크 범위 외. 추후 별도 태스크로 처리.
