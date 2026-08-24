---
name: community-write-path-rpc-only
description: 커뮤니티 테이블의 쓰기는 컬럼 단위 GRANT 때문에 RPC 경유가 강제된다 — .from().update()/delete() 는 42501로 막힌다
metadata:
  type: project
---

`supabase/migrations/20260823000200_community_core.sql` 이 커뮤니티 테이블에
`revoke all` 후 **필요한 컬럼만** `grant update (...)` 를 준다. RLS 정책은 "행"을,
GRANT 는 "컬럼"을 통제하며 **둘 다 통과해야** 하므로, 정책이 맞아도 컬럼 권한이 없으면
`42501` 이다. 그래서 클라이언트에서 다음은 전부 실패한다:

- 소프트 삭제를 `.from('community_posts').update({'status': 'deleted'})` 로 → 42501
- 물리 삭제 `.from().delete()` → 권한 없음
- 카운터 직접 조작 (`like_count` / `view_count` / `comment_count`) → 42501

**How to apply:** 커뮤니티 쓰기 기능을 붙일 때 대응 RPC 가 있는지
`20260823000400_community_feed_views.sql` 에서 먼저 확인한다. 확인된 시그니처:
`community_increment_view(p_post_id uuid) returns integer`,
`community_delete_post(p_id uuid)`, `community_delete_comment(p_id uuid)`,
`community_set_post_status`, `community_set_comment_status`,
`community_ban_user`, `community_unban_user`, `community_resolve_report`, `community_recount`.
카운터는 전부 트리거가 올리므로 클라이언트는 INSERT/DELETE 만 하면 된다
(좋아요는 `community_post_likes` INSERT/DELETE, PK 가 중복을 막으므로 **23505 는 에러가 아니라
"이미 좋아요" 로 간주해 멱등 처리**한다).

낙관적 업데이트는 반드시 `copyWithLike` / `copyWithViewCount` 로 **새 인스턴스를 만들어 대입**한다.
setter 로 필드만 바꾸면 `Rxn`/`RxList` 가 요소 동일성 때문에 리빌드하지 않는다.
상세 → 목록 동기화는 `CommunityController.applyPostUpdate` / `removePost` 로 리스트 요소를 교체한다.

댓글도 같은 구조다(TASK-012 에서 확인):
- 조회는 뷰 `community_comment_feed`. 삭제/숨김 행은 **지워지지 않고** `content`·
  `author_nickname`·`author_avatar_url` 만 NULL 마스킹돼 내려온다(대댓글 고아 방지).
- 삭제는 `community_delete_comment(p_id)` RPC. UPDATE 허용 컬럼은 **`content` 하나뿐**이라
  `edited_at` 을 같이 보내면 42501 이다(트리거가 서버 시각으로 찍는다).
- INSERT 는 테이블 grant 라 컬럼 제약이 없지만, RLS 가 `status='visible'` 을 요구하므로
  **status 를 보내지 말고 기본값에 맡긴다.**
- 1depth·부모 상태 검사는 **INSERT 트리거**다 → `depth_exceeded` / `parent_removed` hint.
- 트리 렌더 시 `parent_id` 가 조회 결과에 없는 대댓글은 반드시 드롭한다. 부모 작성자를
  차단하면 부모 행만 RLS 에 걸려 사라지고 대댓글이 최상위로 튀어나온다.

**Why:** TASK-010 에서 확인. TASK-011~013(작성/수정, 댓글, 신고/차단)이 같은 함정을 그대로 만난다.

관련: [[bottom-nav-tab-binding-pattern]], [[flutter-analyze-crashes]]
