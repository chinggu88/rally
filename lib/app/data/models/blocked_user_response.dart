/// 차단한 사용자 모델 — `user_blocks` 1행 + `public_profiles` 조인 결과.
///
/// 서버 조인이 아니라 클라이언트 hydrate 다. `user_blocks` 는
/// `public_profiles` 뷰와 FK 관계가 없어 PostgREST 임베딩이 되지 않으므로,
/// `ChatMessageRepository._hydrateProfiles` 와 같은 방식으로 두 번 조회해
/// 닉네임/아바타를 붙인다.
///
/// 목록에는 **내가 건 차단만** 담긴다(`ub_select_own` 정책). 나를 차단한
/// 사람은 여기 나타나지 않는다 — 차단 사실을 상대에게 노출하지 않는 설계다.
class BlockedUserResponse {
  /// 차단당한 사용자 UUID — 차단 해제 시 이 값을 쓴다
  String? _blockedId;

  /// 차단한 시각
  DateTime? _createdAt;

  /// 닉네임 — 프로필 조회에 실패했거나 탈퇴한 사용자면 null
  String? _nickname;

  /// 아바타 URL
  String? _avatarUrl;

  BlockedUserResponse({
    String? blockedId,
    DateTime? createdAt,
    String? nickname,
    String? avatarUrl,
  }) {
    _blockedId = blockedId;
    _createdAt = createdAt;
    _nickname = nickname;
    _avatarUrl = avatarUrl;
  }

  String? get blockedId => _blockedId;
  set blockedId(String? value) => _blockedId = value;

  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? value) => _createdAt = value;

  String? get nickname => _nickname;
  set nickname(String? value) => _nickname = value;

  String? get avatarUrl => _avatarUrl;
  set avatarUrl(String? value) => _avatarUrl = value;

  BlockedUserResponse.fromJson(Map<String, dynamic> json) {
    _blockedId = json['blocked_id'] as String?;
    _createdAt = _asDateTime(json['created_at']);
    _nickname = json['nickname'] as String?;
    _avatarUrl = json['avatar_url'] as String?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['blocked_id'] = _blockedId;
    data['created_at'] = _createdAt?.toUtc().toIso8601String();
    data['nickname'] = _nickname;
    data['avatar_url'] = _avatarUrl;
    return data;
  }

  /// 프로필을 붙인 복제본. `RxList` 가 요소 동일성으로 리빌드를 판정하므로
  /// 필드를 바꾸지 않고 새 인스턴스를 만든다.
  BlockedUserResponse copyWithProfile({String? nickname, String? avatarUrl}) {
    return BlockedUserResponse(
      blockedId: _blockedId,
      createdAt: _createdAt,
      nickname: nickname ?? _nickname,
      avatarUrl: avatarUrl ?? _avatarUrl,
    );
  }

  /// 표시할 이름 (`CommunityPostResponse.authorDisplayName` 과 동일 규칙).
  String get displayName {
    final nickname = _nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    final uid = _blockedId;
    if (uid == null || uid.isEmpty) return '탈퇴한 사용자';
    return 'User_${uid.length >= 4 ? uid.substring(0, 4) : uid}';
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
