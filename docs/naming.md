## 1. 클래스(Class)
- **파스칼 케이스(PascalCase)** 사용
- 각 클래스명은 역할을 명확히 나타내도록 작성
- 예시:
  - 컨트롤러: `HomeController`, `AuthController`
  - 모델: `UserModel`, `LoginRequest`
  - 위젯: `CustomButton`, `ProfileCard`

## 2. 함수(Function / Method)
- **카멜 케이스(camelCase)** 사용
- 동사로 시작하여 기능을 명확히 표현
- 예시:
  - `fetchUserData()`
  - `incrementCounter()`
  - `validateEmail()`

## 3. 변수(Variable)
- **카멜 케이스(camelCase)** 사용
- 의미 있는 이름을 사용하고 약어는 지양
- 예시:
  - `userName`, `isLoggedIn`, `profileImageUrl`
- GetX 상태 변수는 **`.obs`**로 선언
  - `final count = 0.obs;`
  - `final userList = <UserModel>[].obs;`

## 4. 상수(Constant)
- **대문자 스네이크 케이스(UPPER_SNAKE_CASE)** 사용
- 전역 상수는 `const` 또는 `static const`로 선언
- 예시:
  - `const MAX_USER_COUNT = 100;`
  - `static const API_BASE_URL = 'https://api.example.com';`

## 5. 파일명(File Name)
- **스네이크 케이스(snake_case)** 사용
- 파일명은 역할과 타입을 포함
- 예시:
  - 컨트롤러: `home_controller.dart`
  - 뷰: `login_view.dart`
  - 모델: `user_model.dart`
  - 바인딩: `home_binding.dart`
  - 유틸: `date_utils.dart`

## 6. 테스트 파일명
- 원본 파일명 뒤에 `_test`를 붙임
- 예시:
  - `home_controller_test.dart`
  - `user_model_test.dart`

## 7. 디렉토리명
- **스네이크 케이스(snake_case)** 사용
- 예시:
  - `controllers/`
  - `views/`
  - `bindings/`
  - `models/`
  - `services/`

---

## 📌 요약
| 항목        | 규칙                  | 예시                          |
|-------------|----------------------|--------------------------------|
| 클래스      | PascalCase           | `HomeController`              |
| 함수/메서드 | camelCase            | `getUserProfile()`             |
| 변수        | camelCase            | `isLoggedIn`                   |
| 상수        | UPPER_SNAKE_CASE     | `API_KEY`                      |
| 파일명      | snake_case           | `home_controller.dart`         |
| 디렉토리명  | snake_case           | `user_profile/`                |
| 테스트파일  | snake_case + `_test` | `home_controller_test.dart`    |

---

## 📎 추가 권장사항
- 약어 사용 최소화 (`usrNm` ❌ → `userName` ✅)
- UI 관련 클래스에는 `Widget` 접미사 사용 (ex. `CustomButtonWidget`)
- GetX Controller는 반드시 `Controller` 접미사 사용