---
name: chat-moderation-gap
description: 라이브 채팅은 커뮤니티와 모더레이션 수준이 다르다 — RLS가 차단을 안 걸러주고, 금칙어·자동숨김·관리자 삭제가 없다
metadata:
  type: project
---

TASK-014 에서 라이브 채팅에 신고·차단을 소급 적용하며 확인한 사실.
채팅과 커뮤니티는 **같은 저장소**(`community_reports` / `user_blocks`)를 쓰지만
**서버 강제 수준이 다르다.** 채팅 쪽을 다시 건드릴 때 커뮤니티 기준으로
가정하면 틀린다.

**차단 필터는 클라이언트가 한다.** `live_match_chat_messages` 의 SELECT 정책은
`lmc_select_all (using true)` 뿐이라 `community_is_blocked()` 가 개입하지 않는다.
커뮤니티처럼 "차단 후 목록만 다시 부르면 된다"가 성립하지 않는다.
`LiveMatchChatController` 는 `_blockedUserIds` 집합을 들고 **초기 로드 ·
loadMore · Realtime INSERT 콜백 세 경로 전부**에서 거른다 — 하나라도 빠지면
차단한 사용자의 새 메시지가 실시간으로 올라온다. 조회 완료 전에 도착한
메시지가 필터를 건너뛰지 않도록 `Future<void>? _blockedReady` 를 각 경로가
먼저 await 한다. 또한 채팅 차단은 **단방향**이다(상대는 내 메시지를 계속 본다).

**`target_type='user'` 신고에는 자동 조치가 없다.** `community_on_report` 는
post/comment 에만 임계값 숨김(음란·불법 1건 / 그 외 3건)을 걸고, user 분기는
**운영자 알림만** 보낸다. 채팅 메시지 신고가 이 경로를 타므로
"신고하면 숨겨진다"고 문서에 쓰면 거짓이 된다.

**아직 없는 것 (제출 전 판단 필요):** `live_match_chat_messages` 에는
금칙어 트리거가 없고(`community_banned_words` 검사는 커뮤니티 테이블 전용),
이용규칙 동의 게이트도 없으며, 정책이 `lmc_delete_own` 뿐이라 **운영자가
남의 채팅 메시지를 지울 수 없다.** Apple 1.2 의 필터·조치 요건이 커뮤니티는
충족되지만 채팅은 부분 충족이다. `appstore_metadata_ko.md` 의 App Review
Notes 는 이 상태를 **사실대로** 적어 두었으니, 마이그레이션으로 메우기 전에는
그 보충 문단을 지우지 마라.

관련: [[community-moderation-surface]], [[community-write-path-rpc-only]]
