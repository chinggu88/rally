/// 커뮤니티 신고 모델 — `community_reports` 1행에 매핑된다.
///
/// 일반 사용자는 RLS(`cr_select_own`)상 **본인이 낸 신고만** 읽을 수 있고,
/// 운영자(`is_app_admin()`)는 전체를 읽는다. 앱에서 실제로 조회하는 쪽은
/// 운영자 흐름 하나뿐이다 — 더보기 시트의 "신고 종결" 항목이 대상 콘텐츠의
/// 미처리 신고를 모아 `community_resolve_report` 로 넘긴다.
///
/// 신고 접수 자체는 이 모델을 쓰지 않는다(INSERT 후 행을 되읽지 않는다).
/// 자동 숨김·운영자 푸시는 서버 트리거(`community_on_report`)가 처리하므로
/// 클라이언트가 결과 행에서 얻을 정보가 없다.
class CommunityReportResponse {
  /// 신고 UUID
  String? _id;

  /// 신고자 UUID
  String? _reporterId;

  /// 대상 종류 (`post` / `comment` / `user`)
  String? _targetType;

  /// 대상 게시글 UUID — `targetType == 'post'` 일 때만 채워진다
  String? _postId;

  /// 대상 댓글 UUID — `targetType == 'comment'` 일 때만 채워진다
  String? _commentId;

  /// 대상 사용자 UUID — `targetType == 'user'` 일 때만 채워진다
  String? _targetUserId;

  /// 사유 코드 (`spam` / `abuse` / `sexual` / `illegal` / `privacy` / `other`)
  String? _reason;

  /// 신고자가 적은 상세 내용 (최대 500자, 선택)
  String? _detail;

  /// 처리 상태 (`pending` / `actioned` / `rejected`)
  String? _status;

  /// 처리 시각 — 미처리면 null
  DateTime? _resolvedAt;

  /// 처리한 운영자 UUID
  String? _resolvedBy;

  /// 처리 메모
  String? _resolutionNote;

  /// 접수 시각
  DateTime? _createdAt;

  CommunityReportResponse({
    String? id,
    String? reporterId,
    String? targetType,
    String? postId,
    String? commentId,
    String? targetUserId,
    String? reason,
    String? detail,
    String? status,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? resolutionNote,
    DateTime? createdAt,
  }) {
    _id = id;
    _reporterId = reporterId;
    _targetType = targetType;
    _postId = postId;
    _commentId = commentId;
    _targetUserId = targetUserId;
    _reason = reason;
    _detail = detail;
    _status = status;
    _resolvedAt = resolvedAt;
    _resolvedBy = resolvedBy;
    _resolutionNote = resolutionNote;
    _createdAt = createdAt;
  }

  String? get id => _id;
  set id(String? value) => _id = value;

  String? get reporterId => _reporterId;
  set reporterId(String? value) => _reporterId = value;

  String? get targetType => _targetType;
  set targetType(String? value) => _targetType = value;

  String? get postId => _postId;
  set postId(String? value) => _postId = value;

  String? get commentId => _commentId;
  set commentId(String? value) => _commentId = value;

  String? get targetUserId => _targetUserId;
  set targetUserId(String? value) => _targetUserId = value;

  String? get reason => _reason;
  set reason(String? value) => _reason = value;

  String? get detail => _detail;
  set detail(String? value) => _detail = value;

  String? get status => _status;
  set status(String? value) => _status = value;

  DateTime? get resolvedAt => _resolvedAt;
  set resolvedAt(DateTime? value) => _resolvedAt = value;

  String? get resolvedBy => _resolvedBy;
  set resolvedBy(String? value) => _resolvedBy = value;

  String? get resolutionNote => _resolutionNote;
  set resolutionNote(String? value) => _resolutionNote = value;

  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? value) => _createdAt = value;

  CommunityReportResponse.fromJson(Map<String, dynamic> json) {
    _id = json['id'] as String?;
    _reporterId = json['reporter_id'] as String?;
    _targetType = json['target_type'] as String?;
    _postId = json['post_id'] as String?;
    _commentId = json['comment_id'] as String?;
    _targetUserId = json['target_user_id'] as String?;
    _reason = json['reason'] as String?;
    _detail = json['detail'] as String?;
    _status = json['status'] as String?;
    _resolvedAt = _asDateTime(json['resolved_at']);
    _resolvedBy = json['resolved_by'] as String?;
    _resolutionNote = json['resolution_note'] as String?;
    _createdAt = _asDateTime(json['created_at']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['reporter_id'] = _reporterId;
    data['target_type'] = _targetType;
    data['post_id'] = _postId;
    data['comment_id'] = _commentId;
    data['target_user_id'] = _targetUserId;
    data['reason'] = _reason;
    data['detail'] = _detail;
    data['status'] = _status;
    data['resolved_at'] = _resolvedAt?.toUtc().toIso8601String();
    data['resolved_by'] = _resolvedBy;
    data['resolution_note'] = _resolutionNote;
    data['created_at'] = _createdAt?.toUtc().toIso8601String();
    return data;
  }

  /// 아직 처리되지 않은 신고인지. `community_resolve_report` 는 `pending`
  /// 행에만 동작하고 그 외에는 `already_resolved` 로 거절한다.
  bool get isPending => _status == null || _status == 'pending';

  static DateTime? _asDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
