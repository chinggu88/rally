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

## 비고

- **API 연동 없음 (기획서 명시)**: 본 3개 태스크는 모두 UI/네비게이션만 구현한다. 인증 API 연동은 추후 별도 태스크로 분리한다.
- **architecture.md 불일치 주의**: `docs/architecture.md`는 다른 프로젝트(testuram)의 구조로 보인다. 본 태스크의 파일 경로는 실제 `lib/app/` 구조(`app`, `match`, `my_info`, `news`, `player` 모듈)를 기반으로 작성되었다. 작업 완료 후 `architecture-update` agent로 동기화 권장.
- **Stitch 프로젝트**: 항상 `307006344264476289` (셔틀콕 뉴스 매거진) 사용.
