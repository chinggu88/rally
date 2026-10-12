# RallyWidget — Xcode 수동 설정

2026-09-10: Xcode에서 **RallyWidgetExtension** 타겟을 생성하고 Runner에 임베드했다.
이 폴더는 해당 타겟에 동기화되므로 Swift 파일은 자동으로 포함된다.
`Info.plist`, `SETUP.md`, entitlements는 리소스 복사에서 제외한다.
Debug / Release / Profile 모두 iOS 14.0, Runner와 같은 개발 팀,
`RallyWidget/RallyWidget.entitlements`를 사용한다.
버전과 빌드 번호는 `Flutter/Generated.xcconfig`의 Flutter 값을 사용한다.
Runner와 위젯의 App Groups 체크 및 위젯의 기기용 서명 빌드를 확인했다.
실제 관심 경기 지정 후 점수 갱신 테스트는 별도로 필요하다.
Runner 전체 시뮬레이터 빌드도 통과했다. 순환 의존성을 피하려면
`Embed Foundation Extensions`를 `Thin Binary`보다 앞에 유지한다.
프로젝트 objectVersion은 설치된 CocoaPods가 지원하는 77(Xcode 16 형식)을 사용한다.

아래는 타겟을 다시 만드는 경우를 위한 절차다. 이미 생성된 타겟을 중복 생성하지 않는다.

## 1. 위젯 익스텐션 타겟 생성

`ios/Runner.xcworkspace`를 Xcode로 연 뒤:

1. **File > New > Target… > iOS > Widget Extension**
2. Product Name: **`RallyWidget`**
3. **"Include Live Activity" 체크 해제** (이번 범위 아님)
4. **"Include Configuration Intent" / "Include Configuration App Intent" 및 "Include Control" 체크 해제** (정적 위젯이면 충분)
5. Finish → "Activate RallyWidget scheme?" → **Activate**

기존 폴더를 먼저 백업한다. Xcode가 같은 이름의 파일을 덮어쓸 수 있다.
생성 후 `RallyWidget.swift`와 `Info.plist`를 백업의 원본으로 복원하고,
템플릿의 별도 `RallyWidgetBundle.swift`는 제거한다(원본에 이미 `@main`이 있다).

## 2. 이 폴더의 파일을 타겟에 추가

Project Navigator에서 `RallyWidget` 그룹에 아래 4개를 추가하고
(**Target Membership = RallyWidget만 체크**, Runner는 체크 해제):

- `MatchSnapshot.swift`
- `RallyWidget.swift`
- `RallyWidgetEntryView.swift`
- `Info.plist` (타겟의 `INFOPLIST_FILE`로 지정)

## 3. Build Settings

`RallyWidget` 타겟에서:

| 설정 | 값 |
|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | **14.0** |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.iksun.rallys.RallyWidget` |
| `DEVELOPMENT_TEAM` | Runner와 동일 |
| `CODE_SIGN_ENTITLEMENTS` | `RallyWidget/RallyWidget.entitlements` |

## 4. App Groups (가장 중요)

**Runner 타겟과 RallyWidget 타겟 양쪽 모두**에서
Signing & Capabilities > **+ Capability > App Groups** > `group.com.iksun.rallys` 체크.

Apple Developer 포털의 App ID에도 이 App Group이 등록되어 있어야 하며
프로비저닝 프로파일 재발급이 필요할 수 있다.

> ⚠️ App Group ID는 아래 **3곳에 하드코딩**되어 있고 하나만 틀려도
> **에러 없이 조용히 빈 위젯**이 된다. 가장 흔한 실패 모드다.
> - `ios/Runner/Runner.entitlements`
> - `ios/RallyWidget/RallyWidget.entitlements` + `MatchSnapshot.appGroupId`
> - `lib/services/favorite_match_service.dart`의 `appGroupId`

## 5. Podfile은 건드리지 않는다

익스텐션은 Flutter/Firebase pod이 전혀 필요 없다(App Group의 UserDefaults만 읽는다).
`Podfile`에 `RallyWidget` target 블록을 추가하면 오히려 빌드가 깨진다.

## 6. 확인

Runner를 실행 → 홈 "오늘 경기" 카드의 별을 탭 → 홈 화면 길게 누르기 > 편집 >
위젯 > "Rally" 검색 > small / medium 둘 다 추가해 표시를 확인한다.
