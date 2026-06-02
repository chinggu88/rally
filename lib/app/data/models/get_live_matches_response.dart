import 'live_match_response.dart';

/// Edge Function `get-live-matches` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "count": 12,
///   "matches": [ { ... LiveMatchResponse ... } ]
/// }
/// ```
class GetLiveMatchesResponse {
  /// 응답에 포함된 라이브 경기 수
  int? _count;

  /// 라이브 경기 목록 (start_date ASC → id ASC)
  List<LiveMatchResponse>? _matches;

  GetLiveMatchesResponse({
    int? count,
    List<LiveMatchResponse>? matches,
  }) {
    _count = count;
    _matches = matches;
  }

  int? get count => _count;
  List<LiveMatchResponse>? get matches => _matches;

  GetLiveMatchesResponse.fromJson(Map<String, dynamic> json) {
    _count = _asInt(json['count']);

    final list = json['matches'];
    if (list is List) {
      _matches = list
          .whereType<Map<String, dynamic>>()
          .map((item) => LiveMatchResponse.fromJson(item))
          .toList();
    } else {
      _matches = null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'count': _count,
      'matches': _matches?.map((item) => item.toJson()).toList(),
    };
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
