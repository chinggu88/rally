import 'player_response.dart';

/// Edge Function `get-players` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "category": "MS",
///   "limit": 30,
///   "offset": 0,
///   "count": 30,
///   "has_more": true,
///   "players": [ { ... PlayerResponse ... } ]
/// }
/// ```
class GetPlayersResponse {
  /// 조회한 종목 코드 (MS/WS/MD/WD/XD)
  String? _category;

  /// 이번 페이지 요청 limit
  int? _limit;

  /// 이번 페이지 요청 offset
  int? _offset;

  /// 이번 페이지에 포함된 선수 수 (limit과 같으면 다음 페이지 있을 수 있음)
  int? _count;

  /// 서버가 알려주는 다음 페이지 존재 가능성. 없으면 클라이언트가
  /// `count < limit` 으로 판단.
  bool? _hasMore;

  /// 선수 목록 (rank 오름차순으로 응답된다고 가정)
  List<PlayerResponse>? _players;

  GetPlayersResponse({
    String? category,
    int? limit,
    int? offset,
    int? count,
    bool? hasMore,
    List<PlayerResponse>? players,
  }) {
    _category = category;
    _limit = limit;
    _offset = offset;
    _count = count;
    _hasMore = hasMore;
    _players = players;
  }

  String? get category => _category;
  set category(String? value) => _category = value;

  int? get limit => _limit;
  set limit(int? value) => _limit = value;

  int? get offset => _offset;
  set offset(int? value) => _offset = value;

  int? get count => _count;
  set count(int? value) => _count = value;

  bool? get hasMore => _hasMore;
  set hasMore(bool? value) => _hasMore = value;

  List<PlayerResponse>? get players => _players;
  set players(List<PlayerResponse>? value) => _players = value;

  GetPlayersResponse.fromJson(Map<String, dynamic> json) {
    _category = json['category'] as String?;

    _limit = _asInt(json['limit']);
    _offset = _asInt(json['offset']);
    _count = _asInt(json['count']);

    final hm = json['has_more'];
    if (hm is bool) {
      _hasMore = hm;
    } else if (hm is num) {
      _hasMore = hm != 0;
    } else if (hm is String) {
      _hasMore = hm.toLowerCase() == 'true';
    } else {
      _hasMore = null;
    }

    final list = json['players'];
    if (list is List) {
      _players = list
          .whereType<Map<String, dynamic>>()
          .map((item) => PlayerResponse.fromJson(item))
          .toList();
    } else {
      _players = null;
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['category'] = _category;
    data['limit'] = _limit;
    data['offset'] = _offset;
    data['count'] = _count;
    data['has_more'] = _hasMore;
    data['players'] = _players?.map((item) => item.toJson()).toList();
    return data;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
