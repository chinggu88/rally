---
name: community-write-gate
description: 커뮤니티 쓰기 진입점은 CommunityOnboardingController.ensureCanWrite() 하나이며, EULA 버전 상수가 DB 함수와 어긋나면 전 사용자가 글을 못 쓴다
metadata:
  type: project
---

TASK-011 에서 만든 작성 게이트는 **`CommunityOnboardingController.ensureCanWrite()`**
(static) 하나뿐이다. 댓글(TASK-012)이 이걸 재사용한다.
**신고·차단(TASK-013)은 게이트를 쓰지 않는다** — 로그인만 확인한다. 서버도
`cr_insert_own` / `ub_insert_own` 에서 `community_can_write()` 를 보지 않는다.
정지당했거나 약관에 동의하지 않은 사용자도 신고는 할 수 있어야 신고 창구가
막히지 않기 때문이다(Apple 1.2). TASK-014 도 같은 규칙이다.
게이트를 `CommunityComposeController` 에 두지 않은 이유: 게이트는 작성 화면에
**진입하기 전에** 통과해야 하는데, 그 컨트롤러는 진입 후에야 생성된다.

**How to apply:** 새 쓰기 액션을 붙일 때
`if (!await CommunityOnboardingController.ensureCanWrite()) return;` 를 먼저 넣는다.
게이트는 (1) 비로그인 → 로그인 화면, (2) `community_banned_until` 미래 → 정지 안내
스낵바, (3) 닉네임 없음 또는 EULA 미동의 → 온보딩 시트를 처리하고 bool 을 돌려준다.
`CommunityModerationRepository` 는 AppBinding·CommunityBinding·PostDetailBinding·
ComposeBinding 네 곳에 fenix 등록돼 있다(게이트가 각 바인딩보다 먼저 도는 경로 대비).

**두 개의 동기화 지점**(어긋나면 조용히 전면 장애):
- `CommunityModerationRepository.eulaVersion` ↔ DB `community_eula_version()`
  (현재 둘 다 `'2026-08-23'`). 어긋나면 `community_can_write()` 가 false 라
  **전 사용자가 글/댓글을 못 쓴다.** 배포 순서는 **DB 먼저**.
- `CommunityTextFilter.normalize()` ↔ DB `community_normalize_text()`
  (`regexp_replace(lower(x), '[^0-9a-z가-힣]', '', 'g')`). 클라는 즉시 피드백용이고
  `community_banned_words.norm` 컬럼을 읽어 `contains` 로 본다. 서버 트리거가 최종 권위.

**이미지 순서 규칙**(어기면 파일이 증발하거나 고아가 남는다):
- 작성: 업로드 → INSERT → **INSERT 실패 시 catch 에서 `removeImages`**.
  `uploadImages` 는 부분 실패 시 자기가 올린 것만 스스로 지우고 rethrow 한다.
- 수정: 새 path 업로드 → UPDATE **성공 후** → 빠진 옛 path 삭제.
- `removeImages` 는 실패해도 던지지 않는다(뒷정리 실패로 "수정 실패"를 띄우면 거짓말).

**Why:** 이 세 가지는 코드만 봐서는 위험도가 안 보이는데, 틀리면 전면 장애나
데이터 유실로 이어진다. TASK-012~014 가 같은 지뢰밭을 지난다.

관련: [[community-write-path-rpc-only]], [[flutter-analyze-crashes]], [[stitch-mcp-unavailable]]
