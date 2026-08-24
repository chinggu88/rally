/// 댓글 작성 요청 파라미터 — `community_comments` INSERT 본문.
///
/// `author_id` 는 이 모델에 두지 않는다. RLS(`cc_insert`)가
/// `author_id = auth.uid()` 를 강제하므로 값의 출처는 세션이어야 하고,
/// 호출부가 임의로 채울 수 있게 두면 42501 을 부르는 실수 지점이 된다.
/// [CommunityCommentRepository.createComment] 가 현재 세션에서 주입한다.
///
/// `status` 도 보내지 않는다 — 컬럼 기본값이 `'visible'` 이고 RLS 가
/// `status = 'visible'` 을 요구하므로 기본값에 맡기는 것이 정확하다.
///
/// [parentId] 가 null 이면 최상위 댓글이다. null 일 때는 키 자체를 빼서
/// INSERT 본문을 최소화한다(컬럼 기본값 NULL 과 결과가 같다).
class CreateCommunityCommentParameter {
  String? postId;
  String? parentId;
  String? content;

  CreateCommunityCommentParameter({this.postId, this.parentId, this.content});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['post_id'] = postId;
    data['content'] = content;
    if (parentId != null && parentId!.isNotEmpty) {
      data['parent_id'] = parentId;
    }
    return data;
  }
}
