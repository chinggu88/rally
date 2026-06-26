/// 라이브 매치 채팅 메시지 모델 — `live_match_chat_messages` 테이블 1행에 매핑.
///
/// authorNickname / authorAvatarUrl 은 `profiles` 테이블을 조인하여 채워주는
/// transient 필드(서버 row에 직접 존재하지 않음). Realtime INSERT 콜백에서는
/// 이 두 필드를 별도로 fetch 해서 채울 수 있다.
class ChatMessageResponse {
  final String id;
  final int liveMatchId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? authorNickname;
  final String? authorAvatarUrl;

  ChatMessageResponse({
    required this.id,
    required this.liveMatchId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.authorNickname,
    this.authorAvatarUrl,
  });

  ChatMessageResponse.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        liveMatchId = _asInt(json['live_match_id']) ?? 0,
        userId = json['user_id'] as String,
        content = (json['content'] as String?) ?? '',
        createdAt = _asDateTime(json['created_at']) ?? DateTime.now(),
        authorNickname = _profileField(json, 'nickname'),
        authorAvatarUrl = _profileField(json, 'avatar_url');

  /// 작성자 정보만 갈아끼운 복제본 — Realtime INSERT 후 별도 profile fetch 결과를
  /// 메시지에 입혀 표시할 때 사용.
  ChatMessageResponse copyWithAuthor({
    String? nickname,
    String? avatarUrl,
  }) {
    return ChatMessageResponse(
      id: id,
      liveMatchId: liveMatchId,
      userId: userId,
      content: content,
      createdAt: createdAt,
      authorNickname: nickname ?? authorNickname,
      authorAvatarUrl: avatarUrl ?? authorAvatarUrl,
    );
  }

  /// Supabase의 `select('*, profiles(...)')` 조인 응답에서 profiles 필드 추출.
  /// 응답이 Map(단일 row)이면 그대로, List이면 first 사용. 없으면 null.
  static String? _profileField(Map<String, dynamic> json, String key) {
    final p = json['profiles'];
    if (p is Map) {
      return p[key] as String?;
    }
    if (p is List && p.isNotEmpty) {
      final first = p.first;
      if (first is Map) return first[key] as String?;
    }
    return null;
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
    return null;
  }
}
