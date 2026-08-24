---
name: bottom-nav-tab-binding-pattern
description: rally 바텀네비 탭 화면에 새 레포지토리/컨트롤러를 추가할 때 AppBinding 이중 등록 + 탭 진입 로딩 정책 (탭별로 다름)
metadata:
  type: project
---

rally의 `AppView`는 바텀 네비 탭 전부를 `IndexedStack`으로 **동시에 마운트**한다
(2026-08 기준 5탭: 홈0 / 경기1 / 선수2 / 커뮤니티3 / 내정보4 — 홈 탭의 모듈 디렉터리 이름은 `home`이다).
즉 `/app` 진입 시점에 모든 탭 View가 `build()`되며, 컨트롤러는 `Get.find()`로 즉시 조회된다.

**1) 의존성은 두 곳에 등록한다.** 모듈 Binding(`<tab>_binding.dart`)은 딥링크로 해당 라우트에
직접 들어올 때만 실행되고, `/app` 경로에서는 `AppBinding`만 실행된다. 탭 컨트롤러가 새
레포지토리를 의존하면 `AppBinding.dependencies()`에도
`Get.lazyPut<Repo>(() => Repo(), fenix: true)` 로 등록해야 하며, 빠뜨리면 앱 진입 즉시
`"Repo not found"` 예외가 난다.

**2) 탭 진입 로딩 정책은 탭마다 다르다.** 같은 IndexedStack 구조 때문에 `onInit()`에서
fetch하면 콜드 스타트마다 그 탭의 쿼리가 붙는다. 두 가지 패턴이 공존한다:
- `PlayerController.reloadFromTab()` — 탭 진입마다 리셋+재로드 (랭킹처럼 항상 최신이 맞는 화면)
- `CommunityController.loadIfNeeded()` — `_hasLoadedOnce` 플래그로 **최초 1회만** 로드
  (글을 읽다 탭을 옮긴 사용자의 스크롤/목록을 보존해야 하는 화면). 갱신은 pull-to-refresh로만.

두 경우 모두 `AppController.changeTab`의 `if (index == xTabIndex && Get.isRegistered<XController>())`
분기에서 호출한다. 새 탭은 **기존 인덱스 상수를 밀지 않는 위치**(끝 또는 내정보 앞)에 넣어
`matchTabIndex`/`playerTabIndex` 하드코딩을 유지한다. 탭이 5개가 되면
`app_theme.dart`의 `bottomNavigationBarTheme` 라벨을 12pt로 낮춰야 320pt 기기에서 안 잘린다.

**Why:** TASK-009(커뮤니티 탭)에서 이 세 가지가 모두 실제 요구사항으로 확인됐다. AppBinding
누락은 기획서가 "가장 확실하게 터지는 것"으로 지목한 항목이다.

관련: [[edge-function-module-pattern]], [[stitch-mcp-unavailable]]
