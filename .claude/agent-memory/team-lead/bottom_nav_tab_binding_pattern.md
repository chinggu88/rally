---
name: bottom-nav-tab-binding-pattern
description: rally에서 바텀 네비게이션 탭 화면(NewsView 등)에 새 레포지토리 의존성을 추가할 때는 AppBinding에도 같이 등록해야 한다
metadata:
  type: project
---

rally의 `AppView`는 4개 탭(News/Match/Player/MyInfo)을 `IndexedStack`으로 동시에 마운트한다. 즉 `AppView` 진입 시점에 4개 탭 View 모두가 `build()`되며, `GetView<X>`의 controller는 `Get.find<X>()`로 즉시 조회된다.

이 때문에 탭 화면용 컨트롤러가 새 레포지토리를 `Get.find<Repo>()`로 주입받을 경우, **NewsBinding에만 fenix로 등록하는 것으로는 부족**하다. `AppBinding`도 라우트 진입 시 한 번 실행되므로 거기서도 같은 레포지토리를 lazyPut으로 보장해야 한다. 그렇지 않으면 AppView 진입 직후 NewsView가 build되며 컨트롤러가 `Get.find<NotRegisteredRepo>()`에서 `"NotRegisteredRepo not found"` 예외를 던진다.

**How to apply:**
- 탭 화면 컨트롤러가 새 레포지토리를 의존하면 두 곳에 등록:
  1. `lib/app/modules/<tab>/bindings/<tab>_binding.dart` — 직접 라우트 진입(딥링크 등) 대비
  2. `lib/app/modules/app/bindings/app_binding.dart` — 바텀 네비 진입 보장
- 등록 방식은 `Get.lazyPut<Repo>(() => Repo(), fenix: true)` — fenix를 줘야 탭 전환·재호출 시에도 재생성된다.

**Why:** 라이브 매치(`get-live-matches`)를 NewsView 홈에 붙이면서 `NewsBinding`에만 `LiveMatchRepository`를 lazyPut했더니, AppView가 NewsView를 즉시 마운트하는 구조 때문에 NewsBinding 실행 전에 NewsController.onInit()이 호출돼 `Get.find<LiveMatchRepository>()`가 실패할 위험을 발견했다. AppBinding에도 추가해 두 번째 안전망을 둔다.

관련: [[edge-function-module-pattern]], [[environment-no-task-tool]]
