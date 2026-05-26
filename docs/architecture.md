```
testuram/lib/
├── main.dart                                    # 앱 진입점 + GetMaterialApp + InitialBinding
│
├── app/                                         # [앱 메인] 애플리케이션 로직
│   │
│   ├── bindings/                                # [글로벌 바인딩] 앱 부팅 시 의존성 주입
│   │   └── initial_binding.dart                 # ApiService / EasyloadingService 영구 등록
│   │
│   ├── routes/                                  # [라우팅] GetX 네비게이션
│   │   ├── app_pages.dart                       # GetPage 매핑 (splash → user_info → onboarding → auth → report)
│   │   └── app_routes.dart                      # 라우트 경로 상수
│   │
│   ├── modules/                                 # [모듈] 기능별 MVC 패턴 구현
│   │   │
│   │   ├── splash/                              # [스플래시] 사용자 상태에 따른 분기 라우팅
│   │   │   ├── bindings/splash_binding.dart
│   │   │   ├── controllers/splash_controller.dart
│   │   │   └── views/splash_view.dart
│   │   │
│   │   ├── onboarding_intro/                    # [온보딩 인트로] 우주 테마 슬라이드 (2페이지)
│   │   │   ├── bindings/onboarding_intro_binding.dart
│   │   │   ├── controllers/onboarding_intro_controller.dart
│   │   │   └── views/onboarding_intro_view.dart
│   │   │
│   │   ├── user_info/                           # [정보 수집] 단계별 폼 (이름·성별·생년월일·시간·지역)
│   │   │   ├── bindings/user_info_binding.dart
│   │   │   ├── controllers/user_info_controller.dart
│   │   │   └── views/
│   │   │       ├── user_info_view.dart
│   │   │       └── widgets/
│   │   │           ├── name_input_widget.dart
│   │   │           ├── hanja_input_widget.dart
│   │   │           ├── gender_select_widget.dart
│   │   │           ├── birth_datetime_widget.dart
│   │   │           └── birth_location_widget.dart
│   │   │
│   │   ├── onboarding/                          # [유람 좌표 분석] 분석 결과 화면 + 회원가입 유도 CTA
│   │   │   ├── bindings/onboarding_binding.dart
│   │   │   ├── controllers/onboarding_controller.dart
│   │   │   └── views/onboarding_view.dart
│   │   │
│   │   ├── auth/                                # [회원가입] SNS 로그인 (카카오 / 구글) + 혼인 여부
│   │   │   ├── bindings/auth_binding.dart
│   │   │   ├── controllers/auth_controller.dart
│   │   │   └── views/
│   │   │       ├── auth_view.dart
│   │   │       └── widgets/marital_status_widget.dart
│   │   │
│   │   └── report/                              # [종합 리포트] 메인 리포트 화면
│   │       ├── bindings/report_binding.dart
│   │       ├── controllers/report_controller.dart
│   │       └── views/report_view.dart
│   │
│   ├── data/                                    # [데이터] 모델 + 레포지토리
│   │   ├── models/
│   │   │   ├── user_info_model.dart             # 온보딩 정보 수집 모델
│   │   │   ├── social_auth_model.dart           # SNS 인증 응답 모델
│   │   │   ├── yuram_coordinate_model.dart      # 유람 좌표 분류 결과
│   │   │   └── report_model.dart                # 종합 리포트 + 섹션 모델
│   │   │
│   │   └── repositories/
│   │       ├── user_info_repository.dart        # 사용자 정보 CRUD API
│   │       ├── auth_repository.dart             # SNS 로그인 / 토큰 갱신 / 로그아웃 API
│   │       └── report_repository.dart           # 좌표 분석 / 종합 리포트 조회 API
│   │
│   └── core/                                    # [코어] 앱 전역 설정 및 유틸리티
│       └── values/
│           ├── app_colors.dart                  # 우주 테마 색상 팔레트
│           └── app_text_styles.dart             # ScreenUtil 기반 텍스트 스타일
│
└── services/                                    # [글로벌 서비스] GetxService 기반 싱글톤
    ├── api_service.dart                         # Dio 래퍼 (토큰 인터셉터 / GET·POST·PATCH·PUT·DELETE)
    └── easyloading_service.dart                 # 로딩 / 토스트 / 정보 메시지
```

## 화면 플로우

```
[Splash]
   │
   ├── 회원가입 완료(sign_up_done) ────────────► [Report]
   │
   ├── 정보 수집 완료(user_info_done) ─────────► [Onboarding] (유람 좌표) ─► [Auth] ─► [Report]
   │
   └── 신규 사용자 ─► [OnboardingIntro] ─► [UserInfo] ─► [Onboarding] ─► [Auth] ─► [Report]
```

## 주요 의존성

- GetX (`get`) — 상태관리 / 라우팅 / DI
- Dio (`dio`) — HTTP 클라이언트 (ApiService에서 래핑)
- GetStorage (`get_storage`) — 로컬 저장소 (사용자 상태 / 토큰)
- ScreenUtil (`flutter_screenutil`) — 반응형 (.w/.h/.sp/.r)
- EasyLoading (`flutter_easyloading`) — 로딩 / 토스트
