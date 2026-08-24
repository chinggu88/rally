/// 게시글 수정 요청 파라미터 — `community_posts` UPDATE 본문.
///
/// **null 이 아닌 필드만 [toJson] 에 담는다** (MODEL_GUIDE 7절 패턴).
/// 여기서는 단순한 부분 갱신 편의를 넘어 필수 요건이다 — 클라이언트에는
/// `(title, content, category, image_paths)` 네 컬럼에만 UPDATE 권한이 있어
/// (`20260823000200_community_core.sql`) 다른 컬럼이 한 개라도 섞이면
/// 요청 전체가 42501 로 거부된다.
///
/// `edited_at` 은 **여기 없다.** 클라이언트가 보내지 않으며 보낼 권한도 없다 —
/// `community_posts_edited_at` 트리거가 title/content/category/image_paths 중
/// 하나라도 실제로 바뀌었을 때 서버 시각으로 찍는다. 기기 시계에 의존하지
/// 않기 위한 설계이고, 카운터 UPDATE 나 관리자 status 변경에는 반응하지 않는다.
class UpdateCommunityPostParameter {
  String? category;
  String? title;
  String? content;
  List<String>? imagePaths;

  UpdateCommunityPostParameter({
    this.category,
    this.title,
    this.content,
    this.imagePaths,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (category != null) data['category'] = category;
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    if (imagePaths != null) data['image_paths'] = imagePaths;
    return data;
  }
}
