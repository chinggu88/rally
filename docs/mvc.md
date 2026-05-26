### 기술 스택

| 기술 | 용도 | 패키지 |
|------|------|--------|
| Flutter | UI 프레임워크 | - |
| GetX | 상태관리, 라우팅, DI | `get` |
| Dio | HTTP 클라이언트 | `dio` |
| Firebase | Core, FCM 푸시 알림 | `firebase_core`, `firebase_messaging` |
| ScreenUtil | 반응형 UI | `flutter_screenutil` |
| GetStorage | 로컬 저장소 | `get_storage` |
| EasyLoading | 로딩 인디케이터 | `flutter_easyloading` |

### 데이터 흐름

```
┌─────────────────────────────────────────────────────────┐
│                        View                              │
│            GetView<Controller> + Obx()                   │
│                  (UI 렌더링)                             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     Controller                           │
│               GetxController + .obs                      │
│          (상태 관리, 비즈니스 로직)                        │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     Repository                           │
│         (API 호출 추상화, 데이터 변환)                     │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     ApiService                           │
│     Dio 래핑, 인터셉터, 토큰 관리, 에러 핸들링             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    REST API Server                       │
└─────────────────────────────────────────────────────────┘
```
### GetX MVC 패턴

| 레이어 | 위치 | 역할 | 상속 |
|--------|------|------|------|
| **Model** | `app/data/models/` | 데이터 구조 (fromJson, toJson) | - |
| **View** | `app/modules/*/views/` | UI 렌더링, 사용자 입력 | `GetView<Controller>` |
| **Controller** | `app/modules/*/controllers/` | 상태 관리, 비즈니스 로직 | `GetxController` |
| **Binding** | `app/modules/*/bindings/` | 의존성 주입 설정 | `Bindings` |
| **Repository** | `app/data/repositories/` | API 호출 추상화 | - |
| **Service** | `services/` | 전역 유틸리티 | `GetxService` |

---