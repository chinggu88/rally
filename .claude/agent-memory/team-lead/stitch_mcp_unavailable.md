---
name: stitch-mcp-unavailable
description: rally 세션에서 Stitch MCP 호출이 인증 오류로 실패한다 — 시안 없이 기존 View 레이아웃을 기준으로 구현한다
metadata:
  type: reference
---

rally 프로젝트의 Stitch projectId 는 `307006344264476289` 이지만,
`mcp__stitch__list_screens` 호출이
`Incompatible auth server: does not support dynamic client registration`
로 실패한다 (2026-08-23 확인). 도구는 목록에 노출되지만 실제 호출이 되지 않는다.

**How to apply:** TASKS.md 가 "UI Agent는 Stitch로 화면을 조회할 것"이라고 지시해도
한 번 시도해 보고 실패하면 즉시 폴백한다. **없는 screenId 를 지어내지 않는다.**
폴백 기준은 화면 유형이 가장 가까운 기존 View 다 — 카드 리스트 화면이면
`lib/app/modules/player/views/player_view.dart`
(Stitch `eeae55cab3614d408743636d325e3b88`, "선수 리스트 (매거진)").
architecture.md 의 Stitch 매핑 표에는 `(Stitch 미대응 — PlayerView 레이아웃 준용)` 으로 남긴다.

**Why:** TASK-009 에서 실제로 실패했고, 팀 리드 지시에도 "인증 실패 시 억지로 진행하지 말라"고
명시돼 있었다. 재시도 비용만 낭비하지 않도록 기록한다.

관련: [[bottom-nav-tab-binding-pattern]], [[edge-function-module-pattern]]
