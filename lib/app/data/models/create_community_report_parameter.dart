/// 신고 작성 요청 파라미터 — `community_reports` INSERT 본문.
///
/// `reporter_id` 는 이 모델에 두지 않는다. RLS(`cr_insert_own`)가
/// `reporter_id = auth.uid()` 를 강제하므로 값의 출처는 세션이어야 하고,
/// 호출부가 임의로 채울 수 있게 두면 42501 을 부르는 실수 지점이 된다.
/// `CommunityModerationRepository.createReport` 가 현재 세션에서 주입한다.
///
/// `status` 도 보내지 않는다 — 컬럼 기본값이 `'pending'` 이고 RLS 가
/// `status = 'pending'` 을 요구하므로 기본값에 맡기는 것이 정확하다.
///
/// **대상 컬럼은 정확히 하나만 채워야 한다.** 서버 CHECK
/// (`community_reports_target_ck`)가 `target_type` 과 짝이 맞는 컬럼 하나만
/// 채워진 행을 허용한다. 그래서 생성자를 대상별로 나눠 두었고 [toJson] 은
/// 해당 키만 내보낸다 — 호출부에서 조합을 틀릴 방법을 없앤 것이다.
class CreateCommunityReportParameter {
  const CreateCommunityReportParameter._({
    required this.targetType,
    required this.reason,
    this.postId,
    this.commentId,
    this.targetUserId,
    this.detail,
  });

  /// 게시글 신고
  factory CreateCommunityReportParameter.post({
    required String postId,
    required String reason,
    String? detail,
  }) {
    return CreateCommunityReportParameter._(
      targetType: targetTypePost,
      postId: postId,
      reason: reason,
      detail: detail,
    );
  }

  /// 댓글 신고
  factory CreateCommunityReportParameter.comment({
    required String commentId,
    required String reason,
    String? detail,
  }) {
    return CreateCommunityReportParameter._(
      targetType: targetTypeComment,
      commentId: commentId,
      reason: reason,
      detail: detail,
    );
  }

  /// 사용자 신고 — 라이브 채팅 신고(TASK-014)도 이 경로를 재사용한다.
  factory CreateCommunityReportParameter.user({
    required String targetUserId,
    required String reason,
    String? detail,
  }) {
    return CreateCommunityReportParameter._(
      targetType: targetTypeUser,
      targetUserId: targetUserId,
      reason: reason,
      detail: detail,
    );
  }

  static const String targetTypePost = 'post';
  static const String targetTypeComment = 'comment';
  static const String targetTypeUser = 'user';

  /// 상세 사유 최대 길이. 서버 CHECK(`char_length(detail) <= 500`)와 같은 값.
  static const int maxDetailLength = 500;

  /// 신고 사유 코드 → 화면 문구. 서버 CHECK 가 허용하는 6종과 정확히 일치하며
  /// **순서가 곧 시트의 라디오 순서**다(기획서 §6-2).
  static const Map<String, String> reasonLabels = <String, String>{
    'spam': '스팸/광고',
    'abuse': '욕설/비방',
    'sexual': '음란물',
    'illegal': '불법 정보',
    'privacy': '개인정보 노출',
    'other': '기타',
  };

  /// `post` / `comment` / `user`
  final String targetType;

  final String? postId;
  final String? commentId;
  final String? targetUserId;

  /// `spam` / `abuse` / `sexual` / `illegal` / `privacy` / `other`
  final String reason;

  /// 상세 내용 (선택, 500자 이내)
  final String? detail;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['target_type'] = targetType;
    switch (targetType) {
      case targetTypePost:
        data['post_id'] = postId;
        break;
      case targetTypeComment:
        data['comment_id'] = commentId;
        break;
      case targetTypeUser:
        data['target_user_id'] = targetUserId;
        break;
    }
    data['reason'] = reason;
    final trimmed = detail?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      data['detail'] = trimmed;
    }
    return data;
  }
}
