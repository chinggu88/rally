---
name: community-moderation-surface
description: 신고·차단·운영자 조치(TASK-013)를 다시 건드릴 때의 함정 — 23505 문구 충돌, 운영자 화면 부재, 차단 후 화면 처리
metadata:
  type: project
---

TASK-013 에서 확정된 규칙. TASK-014(라이브 채팅 소급)가 같은 코드를 재사용한다.

**23505 는 문맥마다 다른 문장이다.** unique_violation 은 닉네임 인덱스 ·
신고 중복(`community_reports_uq_*`) · 재차단(`user_blocks` PK)에서 전부 난다.
그래서 `communityErrorMessage()` 는 코드가 아니라 **위반한 제약 이름**으로
가른다 — PostgREST 가 `message`/`details` 에 실어 보내는 이름을 `contains` 로
본다(`_duplicateMessage`). 새 유니크 제약을 추가하면 여기에 한 줄 넣어야 하고,
**fallback 을 닉네임 문구로 되돌리지 마라**(알 수 없는 위반에 엉뚱한 안내가 된다).
문구는 이 매퍼 한 곳에만 둔다 — 레포지토리에서 또 변환하면 리터럴이 갈라진다.
차단 재시도(PK 23505)만 예외로, 문구가 아니라 **동작**이라 레포지토리에서
**멱등 성공**으로 삼킨다.

**운영자 화면은 없다.** `is_app_admin()` RPC 결과로 기존 더보기 시트
(`CommunityMoreSheet`)에 항목만 얹는다. 판정은 화면 진입 시 1회, 실패하면 false
(안 보이는 쪽이 안전한 실패). 조치는 전부 RPC 다 — [[community-write-path-rpc-only]]
참조. 신고 종결은 건별로 고르지 않고 **대상의 pending 신고 전체를 한 번에** 처리한다.

**차단 후 화면 처리는 대상에 따라 갈린다.** 글 작성자를 차단하면 그 글이 RLS 로
사라지므로 상세를 닫고 목록 refresh. **댓글 작성자를 차단하면 글은 남으므로
상세에 머무른 채 댓글만 다시 읽는다.** 어느 쪽이든 클라이언트가 목록을 걸러내지
않는다 — `community_is_blocked()` 가 서버에서 양방향으로 처리한다.

**관리자 조치 후 카운터는 계산하지 말고 다시 읽어라.** `comment_count` /
`reply_count` 는 `visible ↔ 그 외` 전이마다 `community_bump_comment_count`
트리거가 움직인다. 본인 삭제 경로의 낙관적 `_bumpCommentCount(-1)` 를
관리자 숨김/복구에 재사용하면 **이중 감산**이다. `_refreshPostQuietly()`
(isLoading 을 올리지 않는 재조회)로 서버 값을 받는다. 신고로 댓글이 자동
숨김될 때도 마찬가지다.

**신고 완료 시트는 닫지 않고 "이 사용자 차단하기" CTA 로 전환한다.** 신고 결과가
바로 보이지 않는 것을 차단이 메운다. Apple 리뷰어가 실제로 확인하는 흐름이라
빼면 안 된다. 이미 명시적으로 누른 CTA 라 확인 다이얼로그를 겹치지 않는다.

관련: [[community-write-gate]], [[community-write-path-rpc-only]]
