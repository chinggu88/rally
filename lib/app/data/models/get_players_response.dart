import 'player_response.dart';

/// Edge Function `get-players` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "category": "MS",
///   "count": 100,
///   "players": [ { ... PlayerResponse ... } ]
/// }
/// ```
class GetPlayersResponse {
  /// 조회한 종목 코드 (MS/WS/MD/WD/XD)
  String? _category;

  /// 응답에 포함된 선수 수
  int? _count;

  /// 선수 목록 (rank 오름차순으로 응답된다고 가정)
  List<PlayerResponse>? _players;

  GetPlayersResponse({
    String? category,
    int? count,
    List<PlayerResponse>? players,
  }) {
    _category = category;
    _count = count;
    _players = players;
  }

  String? get category => _category;
  set category(String? value) => _category = value;

  int? get count => _count;
  set count(int? value) => _count = value;

  List<PlayerResponse>? get players => _players;
  set players(List<PlayerResponse>? value) => _players = value;

  GetPlayersResponse.fromJson(Map<String, dynamic> json) {
    _category = json['category'] as String?;

    final countValue = json['count'];
    if (countValue is int) {
      _count = countValue;
    } else if (countValue is num) {
      _count = countValue.toInt();
    } else if (countValue is String) {
      _count = int.tryParse(countValue);
    } else {
      _count = null;
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
    data['count'] = _count;
    data['players'] = _players?.map((item) => item.toJson()).toList();
    return data;
  }
}
