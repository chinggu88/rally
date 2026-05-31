---
name: edge-function-module-pattern
description: rally에서 Supabase Edge Function 매거진 화면 모듈을 추가할 때의 정형 패턴 (TASK-004/005/006에서 세 번 검증됨)
metadata:
  type: project
---

rally는 Supabase Edge Function을 호출하는 매거진 스타일 리스트 화면을 모듈별로 추가한다. TASK-004(match → get-tournaments), TASK-005(player → get-players), TASK-006(match/participants → get-tournament-participants)에서 동일 패턴이 확인되었고, 다음 모듈 추가 시에도 그대로 재사용한다.

**파일 4종 1세트:**
- `lib/app/data/models/<entity>_response.dart` — 단일 항목 (private field + getter/setter + fromJson/toJson, MODEL_GUIDE 컨벤션)
- `lib/app/data/models/get_<entities>_response.dart` — `{ <filterKey>, count, <entities> }` 래퍼
- `lib/app/data/repositories/<entity>_repository.dart` — `Supabase.instance.client.functions.invoke('<edge-fn-name>', method: HttpMethod.get, queryParameters: ...)`
- `lib/app/modules/<module>/{controllers,bindings,views}/` 3개 파일 수정 (placeholder가 이미 있음)

TASK-006처럼 **기존 모듈에 하위 화면을 추가**할 때는 레포지토리에 새 메서드만 append하고 (`getTournamentParticipants` 같은 식), bindings/controllers/views 3개를 **신규 파일**로 생성한다. 라우트 상수도 추가하고 부모 화면(예: tournament_detail_view)의 CTA `onCta`를 새 라우트 `Get.toNamed`로 연결한다.

**Controller 패턴:**
- `RxList<T> items`, `RxBool isLoading`, `RxnString errorMessage`, `Rx<...> selectedFilter` 4종 상태
- `onInit()`에서 자동 1회 fetch
- `fetch<Items>({...filter})`, `refresh<Items>()`, `change<Filter>(...)` 3개 액션
- race-condition 방지를 위해 `int _inflightToken = 0` 카운터 사용 (TASK-005에서 추가됨)

**View 패턴:**
- `Scaffold` + 다크 surface(`#131313`) + `Kinetic Court` AppBar (라임 옐로우 타이틀)
- `RefreshIndicator` + `CustomScrollView`(SliverToBoxAdapter로 헤더/필터/상태영역 분리 — GetX Obx 경고 회피)
- 상태 분기 4단: 로딩 / 에러+재시도버튼 / 빈 결과 / 정상 리스트
- 카드는 `#1C1B1B` 배경 + `#2A2A2A` 보더 + 16px 라운드 + 라임 옐로우(`#C3F400`) 액센트
- Stitch 색상 토큰을 View 파일 상단 static const Color로 보존 (AppColors와 정합되지 않는 디테일만)

**Why:** 신규 모듈 추가 시 위 4종 파일 구조를 그대로 따르면 회귀 위험 없이 일관된 UX를 얻을 수 있다. TASK-004와 005가 거의 동일한 코드 형상을 갖는다는 점이 이를 검증한다.

**How to apply:** 다음에 매거진 리스트형 신규 화면(예: news 모듈 실데이터 연동, 선수 상세, 대회 상세)을 만들 때 이 4종 파일 + Controller/View 패턴을 그대로 재사용하고, 시안에서만 다른 디자인 요소(이미지 유무, 카드 레이아웃)를 변형한다. `unnecessary_getters_setters` info diagnostic은 MODEL_GUIDE 의도된 컨벤션이므로 무시한다.

관련: [[stitch-project-id]], [[environment-no-task-tool]]
