---
name: flutter-analyze-crashes
description: rally 워크스페이스에서 `flutter analyze` 는 code 255로 죽는다 — 정적 검증은 `dart analyze` 로 한다
metadata:
  type: reference
---

이 환경에서 `flutter analyze` 는 analysis server 문제로 **exit code 255** 로 크래시한다
(코드 문제가 아니다, 2026-08-23 확인). `dart analyze lib/` 는 정상 동작한다.

**How to apply:** TASKS.md 의 완료 기준이 "`flutter analyze` 통과"라고 적혀 있어도
`dart analyze lib/` 로 검증한다. 판정 기준은 **error·warning 0건**이며,
아래 두 부류는 프로젝트 기존 상태라 무시한다:

- `unnecessary_getters_setters` (info) — `docs/api/MODEL_GUIDE.md` 가 의도한 컨벤션
- `constant_identifier_names` (info) — `Routes` 의 대문자 상수 관례

**새 워크트리에서는 `flutter pub get` 을 먼저 돌려야 한다.** `.dart_tool/package_config.json`
이 없으면 `dart analyze` 가 실패하지 않고 **Flutter SDK 타입을 못 찾은 채 8000건대 가짜
warning**(`override_on_non_overriding_member` 도배)을 뱉는다. 숫자가 기준선보다 수십 배
크면 내 코드 문제가 아니라 의존성 미해결이다 — `ls .dart_tool` 로 먼저 확인한다
(2026-08-26 TASK-015/016 에서 확인).

기준 카운트는 태스크가 쌓이면서 info 만 늘어난다 — **error 2 는 고정**이다.
TASK-010 직후 **169 issues**, TASK-016 직후 **201 issues**, TASK-017/018 시점 **205 issues**
이고 모두 선행 이슈다:
- error 2건은 `lib/main.dart` 의 `firebase_options.dart` — `.gitignore` 된 생성 파일이라
  워크트리에 없어서 나는 것이지 코드 결함이 아니다
- **warning 은 현재 0건**이다(2026-08-26 TASK-018 실측). 예전에 4건이던 `home/` ·
  `live_match_chat/` 미사용 선언은 정리됐다 — 지시문에 적힌 수치보다 매번 실측을 믿는다

**`dart format` 을 파일 전체에 돌리지 마라.** `live_match_chat_view` · `profile_edit_view` ·
`login_view` · `sign_up_view` 는 현재 포맷터 출력과 다르다(포맷 강제가 없다). 수정한 파일에
`dart format` 을 돌리면 내 변경과 무관한 줄까지 바뀐다 — 위젯 래핑처럼 들여쓰기가 밀리는
편집은 해당 블록만 손으로 2칸 밀어 넣는다.

이 숫자보다 늘었으면 내가 넣은 것이다.

관련: [[environment-no-task-tool]]
