/// 커뮤니티 댓글 모델 — 뷰 `community_comment_feed` 1행에 매핑된다.
///
/// 테이블(`community_comments`)이 아니라 뷰를 조회한다. 뷰는 작성자 프로필을
/// 조인해 주는 동시에, 삭제·숨김 댓글의 `content` / `author_nickname` /
/// `author_avatar_url` 을 **NULL 로 마스킹**해서 내려준다.
///
/// 행 자체는 남는다 — 대댓글이 고아가 되지 않게 스레드 구조를 유지하기
/// 위해서다(`cc_select` 정책의 `reply_count > 0` 조건). 그래서 클라이언트는
/// `content == null` 인 행을 "삭제된 댓글입니다" 툼스톤으로 그린다.
/// 툼스톤 문구는 모델이 아니라 위젯이 만든다 — 모델은 표시 문자열을 갖지 않는다.
class CommunityCommentResponse {
  /// 댓글 UUID
  String? _id;

  /// 소속 게시글 UUID
  String? _postId;

  /// 부모 댓글 UUID — null이면 최상위 댓글, 있으면 대댓글(1depth 까지)
  String? _parentId;

  /// 작성자 UUID — 탈퇴한 사용자는 null (`on delete set null`)
  String? _authorId;

  /// 본문 (1~1000자). 삭제·숨김 댓글은 뷰에서 null 로 마스킹된다.
  String? _content;

  /// 대댓글 수 (비정규화 카운터, 서버 트리거가 관리)
  int? _replyCount;

  /// 노출 상태 (`visible` / `hidden` / `deleted`)
  String? _status;

  /// 마지막 수정 시각 — 수정 이력이 없으면 null
  DateTime? _editedAt;

  /// 작성 시각 — 목록 정렬 기준(오름차순)
  DateTime? _createdAt;

  /// 갱신 시각
  DateTime? _updatedAt;

  /// 작성자 닉네임 — 삭제·숨김 댓글은 null 로 마스킹된다
  String? _authorNickname;

  /// 작성자 아바타 URL — 삭제·숨김 댓글은 null 로 마스킹된다
  String? _authorAvatarUrl;

  CommunityCommentResponse({
    String? id,
    String? postId,
    String? parentId,
    String? authorId,
    String? content,
    int? replyCount,
    String? status,
    DateTime? editedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorNickname,
    String? authorAvatarUrl,
  }) {
    _id = id;
    _postId = postId;
    _parentId = parentId;
    _authorId = authorId;
    _content = content;
    _replyCount = replyCount;
    _status = status;
    _editedAt = editedAt;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _authorNickname = authorNickname;
    _authorAvatarUrl = authorAvatarUrl;
  }

  String? get id => _id;
  set id(String? value) => _id = value;

  String? get postId => _postId;
  set postId(String? value) => _postId = value;

  String? get parentId => _parentId;
  set parentId(String? value) => _parentId = value;

  String? get authorId => _authorId;
  set authorId(String? value) => _authorId = value;

  String? get content => _content;
  set content(String? value) => _content = value;

  int? get replyCount => _replyCount;
  set replyCount(int? value) => _replyCount = value;

  String? get status => _status;
  set status(String? value) => _status = value;

  DateTime? get editedAt => _editedAt;
  set editedAt(DateTime? value) => _editedAt = value;

  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? value) => _createdAt = value;

  DateTime? get updatedAt => _updatedAt;
  set updatedAt(DateTime? value) => _updatedAt = value;

  String? get authorNickname => _authorNickname;
  set authorNickname(String? value) => _authorNickname = value;

  String? get authorAvatarUrl => _authorAvatarUrl;
  set authorAvatarUrl(String? value) => _authorAvatarUrl = value;

  CommunityCommentResponse.fromJson(Map<String, dynamic> json) {
    _id = json['id'] as String?;
    _postId = json['post_id'] as String?;
    _parentId = json['parent_id'] as String?;
    _authorId = json['author_id'] as String?;
    _content = json['content'] as String?;
    _replyCount = _asInt(json['reply_count']);
    _status = json['status'] as String?;
    _editedAt = _asDateTime(json['edited_at']);
    _createdAt = _asDateTime(json['created_at']);
    _updatedAt = _asDateTime(json['updated_at']);
    _authorNickname = json['author_nickname'] as String?;
    _authorAvatarUrl = json['author_avatar_url'] as String?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['post_id'] = _postId;
    data['parent_id'] = _parentId;
    data['author_id'] = _authorId;
    data['content'] = _content;
    data['reply_count'] = _replyCount;
    data['status'] = _status;
    data['edited_at'] = _editedAt?.toUtc().toIso8601String();
    data['created_at'] = _createdAt?.toUtc().toIso8601String();
    data['updated_at'] = _updatedAt?.toUtc().toIso8601String();
    data['author_nickname'] = _authorNickname;
    data['author_avatar_url'] = _authorAvatarUrl;
    return data;
  }

  /// 대댓글 여부. 서버가 1depth 를 강제하므로 이 값이 true 면 더 이상
  /// 답글을 달 수 없다(트리거 `community_comments_enforce_depth`).
  bool get isReply => _parentId != null && _parentId!.isNotEmpty;

  /// 삭제·숨김되어 툼스톤으로 그려야 하는 댓글인지.
  ///
  /// `status` 를 기준으로 본다. 뷰가 본문을 NULL 로 마스킹하는 조건과 같은
  /// 조건이므로 `content == null` 과 결과가 일치하지만, 판정 근거를 상태값에
  /// 두어야 "본문이 비어 보이는 정상 댓글" 같은 오판이 생기지 않는다.
  bool get isRemoved => _status != null && _status != 'visible';

  /// 삭제된 상태로 갈아끼운 복제본.
  ///
  /// 본인 댓글 삭제 직후 화면을 서버 재조회 없이 툼스톤으로 바꾸기 위한 것이다.
  /// 뷰가 내려주는 마스킹과 같은 모양(본문·작성자 NULL)을 로컬에서 재현한다.
  /// setter 로 필드만 바꾸면 `RxList` 가 요소 동일성 때문에 리빌드하지 않으므로
  /// 반드시 새 인스턴스를 만들어 교체한다.
  CommunityCommentResponse copyWithRemoved() {
    return CommunityCommentResponse(
      id: _id,
      postId: _postId,
      parentId: _parentId,
      authorId: _authorId,
      content: null,
      replyCount: _replyCount,
      status: 'deleted',
      editedAt: _editedAt,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      authorNickname: null,
      authorAvatarUrl: null,
    );
  }

  /// 표시할 작성자 이름 (`CommunityPostResponse.authorDisplayName` 과 동일 규칙).
  /// 툼스톤에서는 쓰이지 않는다 — 삭제 댓글은 작성자를 노출하지 않는다.
  String get authorDisplayName {
    final nickname = _authorNickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    final uid = _authorId;
    if (uid == null || uid.isEmpty) return '탈퇴한 사용자';
    return 'User_${uid.length >= 4 ? uid.substring(0, 4) : uid}';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
