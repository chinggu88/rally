---
name: environment-no-task-tool
description: 이 rally 세션에서는 Task(서브에이전트 호출) 도구가 deferred tool 목록에 포함되지 않아 사용 불가
metadata:
  type: reference
---

이 프로젝트의 Claude Code 세션에서는 서브에이전트를 호출하는 `Task` 도구가 deferred tool 목록에서 노출되지 않는다 (`ToolSearch`로 검색해도 매칭되지 않음). `TeamCreate`는 보였지만 일회성 태스크 분배에는 과한 도구다.

**How to apply:** team-lead 가이드가 "API Agent / Controller Agent / UI Agent / Architecture Updater 서브에이전트를 호출해 작업을 분배하라"고 하지만, 이 환경에서는 그게 불가능하다. 대신 team-lead가 각 서브에이전트의 `.claude/agents/*.md` 가이드를 직접 읽어, 동일한 규칙(MODEL_GUIDE.md / controller.md / screen.md, Stitch 매핑, 자동 실행 모드)에 맞춰 본인이 직접 파일을 생성/수정해야 한다. 이게 사용자가 의도한 결과이며, 사용자에게 "Task 도구가 없다"고 일일이 물어볼 필요 없이 자동 실행한다.

**Why:** 첫 시도에서 `Task` 호출이 InputValidationError가 날 위험이 있었고, ToolSearch로도 매칭되지 않음을 확인했다. 자동 실행 모드 규칙(확인 질문 금지)을 따라 직접 수행하는 것이 정답이다.

관련: [[stitch-project-id]]
