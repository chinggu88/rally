import 'package:supabase_flutter/supabase_flutter.dart';

/// 커뮤니티 게시글 모델 — 뷰 `community_post_feed` 1행에 매핑된다.
///
/// 테이블(`community_posts`)이 아니라 뷰를 조회하므로 작성자 프로필
/// (`author_nickname` / `author_avatar_url`)과 `is_liked` 가 한 행에 이미
/// 들어 있다. 별도 조인/후처리가 필요 없다.
///
/// 응답 래퍼(`GetCommunityPostsResponse`)는 만들지 않는다 — Edge Function이
/// 아니라 `.from()` 직접 접근이라 봉투가 없다.
class CommunityPostResponse {
  /// 게시글 UUID
  String? _id;

  /// 작성자 UUID — 탈퇴한 사용자는 null (`on delete set null`)
  String? _authorId;

  /// 카테고리 코드 (`free` / `match` / `gear` / `partner`)
  String? _category;

  /// 제목 (1~100자)
  String? _title;

  /// 본문 (1~5000자)
  String? _content;

  /// 스토리지 상대 경로 목록 (최대 5장). 표시용 URL은 [imageUrls] 로 변환한다.
  List<String>? _imagePaths;

  /// 좋아요 수 (비정규화 카운터)
  int? _likeCount;

  /// 댓글 수 (비정규화 카운터)
  int? _commentCount;

  /// 조회 수 (비정규화 카운터)
  int? _viewCount;

  /// 노출 상태 (`visible` / `hidden` / `deleted`)
  String? _status;

  /// 마지막 수정 시각 — 수정 이력이 없으면 null
  DateTime? _editedAt;

  /// 작성 시각 — 목록 커서 페이지네이션 기준값
  DateTime? _createdAt;

  /// 갱신 시각 (카운터 변동 포함)
  DateTime? _updatedAt;

  /// 작성자 닉네임 — `public_profiles` 조인 결과. 탈퇴/미설정 시 null
  String? _authorNickname;

  /// 작성자 아바타 URL — 없으면 null
  String? _authorAvatarUrl;

  /// 현재 로그인 사용자의 좋아요 여부 (비로그인은 항상 false)
  bool? _isLiked;

  CommunityPostResponse({
    String? id,
    String? authorId,
    String? category,
    String? title,
    String? content,
    List<String>? imagePaths,
    int? likeCount,
    int? commentCount,
    int? viewCount,
    String? status,
    DateTime? editedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorNickname,
    String? authorAvatarUrl,
    bool? isLiked,
  }) {
    _id = id;
    _authorId = authorId;
    _category = category;
    _title = title;
    _content = content;
    _imagePaths = imagePaths;
    _likeCount = likeCount;
    _commentCount = commentCount;
    _viewCount = viewCount;
    _status = status;
    _editedAt = editedAt;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _authorNickname = authorNickname;
    _authorAvatarUrl = authorAvatarUrl;
    _isLiked = isLiked;
  }

  String? get id => _id;
  set id(String? value) => _id = value;

  String? get authorId => _authorId;
  set authorId(String? value) => _authorId = value;

  String? get category => _category;
  set category(String? value) => _category = value;

  String? get title => _title;
  set title(String? value) => _title = value;

  String? get content => _content;
  set content(String? value) => _content = value;

  List<String>? get imagePaths => _imagePaths;
  set imagePaths(List<String>? value) => _imagePaths = value;

  int? get likeCount => _likeCount;
  set likeCount(int? value) => _likeCount = value;

  int? get commentCount => _commentCount;
  set commentCount(int? value) => _commentCount = value;

  int? get viewCount => _viewCount;
  set viewCount(int? value) => _viewCount = value;

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

  bool? get isLiked => _isLiked;
  set isLiked(bool? value) => _isLiked = value;

  CommunityPostResponse.fromJson(Map<String, dynamic> json) {
    _id = json['id'] as String?;
    _authorId = json['author_id'] as String?;
    _category = json['category'] as String?;
    _title = json['title'] as String?;
    _content = json['content'] as String?;
    _imagePaths =
        json['image_paths'] != null
            ? List<String>.from(
              (json['image_paths'] as List).map((e) => e.toString()),
            )
            : null;
    _likeCount = _asInt(json['like_count']);
    _commentCount = _asInt(json['comment_count']);
    _viewCount = _asInt(json['view_count']);
    _status = json['status'] as String?;
    _editedAt = _asDateTime(json['edited_at']);
    _createdAt = _asDateTime(json['created_at']);
    _updatedAt = _asDateTime(json['updated_at']);
    _authorNickname = json['author_nickname'] as String?;
    _authorAvatarUrl = json['author_avatar_url'] as String?;
    _isLiked = json['is_liked'] as bool?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['author_id'] = _authorId;
    data['category'] = _category;
    data['title'] = _title;
    data['content'] = _content;
    data['image_paths'] = _imagePaths;
    data['like_count'] = _likeCount;
    data['comment_count'] = _commentCount;
    data['view_count'] = _viewCount;
    data['status'] = _status;
    data['edited_at'] = _editedAt?.toUtc().toIso8601String();
    data['created_at'] = _createdAt?.toUtc().toIso8601String();
    data['updated_at'] = _updatedAt?.toUtc().toIso8601String();
    data['author_nickname'] = _authorNickname;
    data['author_avatar_url'] = _authorAvatarUrl;
    data['is_liked'] = _isLiked;
    return data;
  }

  /// 좋아요 상태만 갈아끼운 복제본.
  ///
  /// 낙관적 토글에서 setter로 필드를 바꾸면 `RxList` 는 요소 동일성이 유지되어
  /// 변경을 감지하지 못한다. 새 인스턴스를 만들어 `_posts[i] = newPost` 로
  /// 교체해야 리빌드된다. (`ChatMessageResponse.copyWithAuthor` 선례)
  CommunityPostResponse copyWithLike({int? likeCount, bool? isLiked}) {
    return CommunityPostResponse(
      id: _id,
      authorId: _authorId,
      category: _category,
      title: _title,
      content: _content,
      imagePaths: _imagePaths,
      likeCount: likeCount ?? _likeCount,
      commentCount: _commentCount,
      viewCount: _viewCount,
      status: _status,
      editedAt: _editedAt,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      authorNickname: _authorNickname,
      authorAvatarUrl: _authorAvatarUrl,
      isLiked: isLiked ?? _isLiked,
    );
  }

  /// 조회 수만 갈아끼운 복제본.
  ///
  /// [copyWithLike] 와 같은 이유로 setter 대신 새 인스턴스를 만든다 —
  /// 상세 진입 시 RPC가 돌려준 `view_count` 를 목록 `RxList` 에 되반영할 때
  /// 요소 동일성이 유지되면 리빌드되지 않는다.
  CommunityPostResponse copyWithViewCount(int viewCount) {
    return CommunityPostResponse(
      id: _id,
      authorId: _authorId,
      category: _category,
      title: _title,
      content: _content,
      imagePaths: _imagePaths,
      likeCount: _likeCount,
      commentCount: _commentCount,
      viewCount: viewCount,
      status: _status,
      editedAt: _editedAt,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      authorNickname: _authorNickname,
      authorAvatarUrl: _authorAvatarUrl,
      isLiked: _isLiked,
    );
  }

  /// 댓글 수만 갈아끼운 복제본.
  ///
  /// [copyWithLike] 와 같은 이유로 setter 대신 새 인스턴스를 만든다 —
  /// 댓글 작성/삭제 직후 상세 하단 액션바와 목록 카드의 댓글 수를 낙관적으로
  /// 반영할 때 요소 동일성이 유지되면 리빌드되지 않는다.
  ///
  /// 실제 카운터는 `community_bump_comment_count` 트리거가 관리한다. 여기서
  /// 만드는 값은 다음 서버 조회 전까지만 쓰이는 임시값이다.
  CommunityPostResponse copyWithCommentCount(int commentCount) {
    return CommunityPostResponse(
      id: _id,
      authorId: _authorId,
      category: _category,
      title: _title,
      content: _content,
      imagePaths: _imagePaths,
      likeCount: _likeCount,
      commentCount: commentCount,
      viewCount: _viewCount,
      status: _status,
      editedAt: _editedAt,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      authorNickname: _authorNickname,
      authorAvatarUrl: _authorAvatarUrl,
      isLiked: _isLiked,
    );
  }

  /// 목록/상세에 표시할 작성자 이름.
  ///
  /// 커뮤니티는 첫 글 작성 전 닉네임을 강제하므로 정상 흐름에서는 비지 않지만,
  /// 탈퇴(`author_id == null`)와 과거 데이터를 방어한다.
  String get authorDisplayName {
    final nickname = _authorNickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    final uid = _authorId;
    if (uid == null || uid.isEmpty) return '탈퇴한 사용자';
    return 'User_${uid.length >= 4 ? uid.substring(0, 4) : uid}';
  }

  /// 스토리지 상대 경로를 공개 URL로 변환한 목록.
  List<String> get imageUrls {
    final paths = _imagePaths;
    if (paths == null || paths.isEmpty) return const <String>[];
    final storage = Supabase.instance.client.storage.from(_bucket);
    return paths
        .where((p) => p.trim().isNotEmpty)
        .map(storage.getPublicUrl)
        .toList();
  }

  /// 목록 카드 썸네일용 — 첫 번째 이미지의 공개 URL. 없으면 null.
  String? get thumbnailUrl {
    final urls = imageUrls;
    return urls.isEmpty ? null : urls.first;
  }

  /// 커뮤니티 이미지 스토리지 버킷 (public)
  static const String _bucket = 'community';

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
