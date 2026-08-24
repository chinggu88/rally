/// 게시글 작성 요청 파라미터 — `community_posts` INSERT 본문.
///
/// `author_id` 는 이 모델에 두지 않는다. RLS(`cp_insert`)가
/// `author_id = auth.uid()` 를 강제하므로 값의 출처는 세션이어야 하고,
/// 호출부가 임의로 채울 수 있게 두면 42501 을 부르는 실수 지점이 된다.
/// [CommunityPostRepository.createPost] 가 현재 세션에서 주입한다.
///
/// `image_paths` 는 **공개 URL이 아니라 스토리지 상대 경로**다
/// (`{uid}/{draftId}/{index}_{ts}.jpg`). RLS 가 모든 원소의 첫 세그먼트가
/// 자기 uid 인지 검사하므로 URL을 넣으면 INSERT 자체가 막힌다.
class CreateCommunityPostParameter {
  String? category;
  String? title;
  String? content;
  List<String>? imagePaths;

  CreateCommunityPostParameter({
    this.category,
    this.title,
    this.content,
    this.imagePaths,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['category'] = category;
    data['title'] = title;
    data['content'] = content;
    // NOT NULL DEFAULT '{}' 컬럼이라 null 대신 빈 배열을 보낸다.
    data['image_paths'] = imagePaths ?? <String>[];
    return data;
  }
}
