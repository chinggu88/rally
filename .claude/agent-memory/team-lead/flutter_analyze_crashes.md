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

기준 시점(TASK-010 완료 직후) 전체 카운트는 **169 issues / error 2 / warning 4** 이고,
모두 선행 이슈다:
- error 2건은 `lib/main.dart` 의 `firebase_options.dart` — `.gitignore` 된 생성 파일이라
  워크트리에 없어서 나는 것이지 코드 결함이 아니다
- warning 4건은 `home/` · `live_match_chat/` 의 미사용 선언/임포트

이 숫자보다 늘었으면 내가 넣은 것이다.

관련: [[environment-no-task-tool]]
