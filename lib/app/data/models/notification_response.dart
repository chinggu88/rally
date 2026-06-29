/// 알림 응답 모델 — `notifications` 테이블 1행에 매핑.
///
/// send-push edge function이 발송 결과를 같은 행의 status/sent_at에 update하므로,
/// 클라이언트는 sent_at 기준 최신순으로 조회하면 된다.
class NotificationResponse {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? status;
  final DateTime? sentAt;
  final DateTime? createdAt;

  NotificationResponse({
    required this.id,
    required this.title,
    required this.body,
    this.data,
    this.status,
    this.sentAt,
    this.createdAt,
  });

  NotificationResponse.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = (json['title'] as String?) ?? '',
        body = (json['body'] as String?) ?? '',
        data = _asMap(json['data']),
        status = json['status'] as String?,
        sentAt = _asDateTime(json['sent_at']),
        createdAt = _asDateTime(json['created_at']);

  /// 화면 정렬용 시각 — sent_at 우선, 없으면 created_at, 둘 다 없으면 epoch.
  DateTime get displayTime =>
      sentAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// data['type'] (예: 'ranking_change') — 클라이언트 라우팅에 사용.
  String? get type => data?['type'] as String?;

  /// data['changes'] — 랭킹변동 요약 알림의 선수별 상세 목록.
  /// 요약 알림이 아니거나 상세가 없으면 빈 리스트.
  List<RankingChangeItem> get rankingChanges {
    final raw = data?['changes'];
    if (raw is! List) return const <RankingChangeItem>[];
    return raw
        .whereType<Map>()
        .map((e) => RankingChangeItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

/// 랭킹변동 요약 알림(`data.changes[]`)의 선수 1명 변동 항목.
class RankingChangeItem {
  final String memberId;
  final String playerName;
  final String category;
  final int rank;
  final int rankChange;

  RankingChangeItem({
    required this.memberId,
    required this.playerName,
    required this.category,
    required this.rank,
    required this.rankChange,
  });

  RankingChangeItem.fromJson(Map<String, dynamic> json)
      : memberId = (json['member_id'] ?? '').toString(),
        playerName = (json['player_name'] as String?) ?? '',
        category = (json['category'] as String?) ?? '',
        rank = _asInt(json['rank']),
        rankChange = _asInt(json['rank_change']);

  /// rank가 상승했는지 (양수=상승).
  bool get isUp => rankChange > 0;

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
