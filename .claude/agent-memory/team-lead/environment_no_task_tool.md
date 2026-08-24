---
name: environment-no-task-tool
description: rally 세션에서 서브에이전트(api/controller/ui-agent) 위임은 기본적으로 하지 않고 team-lead가 직접 구현한다
metadata:
  type: feedback
---

`api-agent` / `controller-agent` / `ui-agent` / `architecture-update` 서브에이전트 타입이
정의돼 있어도, 이 프로젝트의 세션 지시는 **"사용자가 요청하지 않으면 Agent 도구를 호출하지 말 것"**
이다. 실제로 팀 리드로부터 오는 태스크 지시도 "네가 직접 처리해라" 형태로 온다.

**How to apply:** team-lead 가이드가 "각 Agent에게 작업을 분배하라"고 해도, 각 서브에이전트의
`.claude/agents/*.md` 가이드와 참조 문서(`docs/api/MODEL_GUIDE.md`, `docs/controller/controller.md`,
`docs/widget/screen.md`)를 team-lead가 직접 읽고 동일한 규칙으로 본인이 파일을 생성/수정한다.
API → Controller → UI 순서와 "라우트/architecture.md/TASKS.md는 마지막에 일괄 처리" 규칙은
그대로 지킨다.

**Why:** 자동 실행 모드(확인 질문 금지)와 "Agent 도구 임의 호출 금지"가 동시에 걸려 있어,
위임을 시도하면 지시 위반이거나 불필요한 왕복이 된다. TASK-004~009 에서 직접 구현이
의도된 결과임이 반복 확인됐다.

관련: [[stitch-mcp-unavailable]], [[edge-function-module-pattern]]
