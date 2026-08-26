/// 타인 프로필 모델 — 뷰 `public_profiles` 1행에 매핑된다.
///
/// `profiles` 테이블이 아니라 뷰를 조회한다. 이 뷰는 `security_invoker` 가
/// 없어 RLS 를 우회하고 `anon` 에도 select 가 열려 있으므로, 노출 컬럼을
/// **`id` · `nickname` · `avatar_url` · `created_at` 4개로 최소화**해 정당화한
/// 케이스다(`20260630010000` / `20260826000100` 마이그레이션 주석 참조).
/// 필드를 늘리고 싶으면 이 뷰를 키우지 말고 `security_invoker` 를 켠 별도
/// 뷰를 만든다.
///
/// 가입일 표시 문자열(`2026년 6월 가입`)은 모델이 만들지 않는다 —
/// 표시 형식은 위젯(`CommunityProfileSheet`)의 책임이다.
class PublicProfileResponse {
  /// 사용자 UUID (= `auth.users.id`)
  String? _id;

  /// 닉네임 — 미설정이면 null
  String? _nickname;

  /// 아바타 공개 URL — 미설정이면 null
  String? _avatarUrl;

  /// 가입 시각
  DateTime? _createdAt;

  PublicProfileResponse({
    String? id,
    String? nickname,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    _id = id;
    _nickname = nickname;
    _avatarUrl = avatarUrl;
    _createdAt = createdAt;
  }

  String? get id => _id;
  set id(String? value) => _id = value;

  String? get nickname => _nickname;
  set nickname(String? value) => _nickname = value;

  String? get avatarUrl => _avatarUrl;
  set avatarUrl(String? value) => _avatarUrl = value;

  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? value) => _createdAt = value;

  PublicProfileResponse.fromJson(Map<String, dynamic> json) {
    _id = json['id'] as String?;
    _nickname = json['nickname'] as String?;
    _avatarUrl = json['avatar_url'] as String?;
    _createdAt = _asDateTime(json['created_at']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['nickname'] = _nickname;
    data['avatar_url'] = _avatarUrl;
    data['created_at'] = _createdAt?.toUtc().toIso8601String();
    return data;
  }

  /// 표시할 이름 (`CommunityPostResponse.authorDisplayName` 과 동일 규칙).
  String get displayName {
    final nickname = _nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    final uid = _id;
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
