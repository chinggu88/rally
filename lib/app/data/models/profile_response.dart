/// 사용자 프로필 응답 모델 — `profiles` 테이블 1행에 매핑.
///
/// id = auth.users.id. 닉네임/아바타는 미설정 시 null이다.
class ProfileResponse {
  final String id;
  final String? nickname;
  final String? avatarUrl;
  final bool notificationsEnabled;

  ProfileResponse({
    required this.id,
    this.nickname,
    this.avatarUrl,
    this.notificationsEnabled = true,
  });

  ProfileResponse.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        nickname = json['nickname'] as String?,
        avatarUrl = json['avatar_url'] as String?,
        notificationsEnabled = (json['notifications_enabled'] as bool?) ?? true;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'notifications_enabled': notificationsEnabled,
      };

  ProfileResponse copyWith({
    String? nickname,
    String? avatarUrl,
    bool? notificationsEnabled,
  }) {
    return ProfileResponse(
      id: id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
