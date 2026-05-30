import 'tournament_match_response.dart';

/// Edge Function `get-tournament-matches` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "tournament_id": 123,
///   "count": 48,
///   "matches": [ { ... TournamentMatchResponse ... } ]
/// }
/// ```
class GetTournamentMatchesResponse {
  /// 조회한 대회 ID
  int? _tournamentId;

  /// 응답에 포함된 경기 수
  int? _count;

  /// 경기 목록 (match_time 오름차순)
  List<TournamentMatchResponse>? _matches;

  GetTournamentMatchesResponse({
    int? tournamentId,
    int? count,
    List<TournamentMatchResponse>? matches,
  }) {
    _tournamentId = tournamentId;
    _count = count;
    _matches = matches;
  }

  int? get tournamentId => _tournamentId;
  int? get count => _count;
  List<TournamentMatchResponse>? get matches => _matches;

  GetTournamentMatchesResponse.fromJson(Map<String, dynamic> json) {
    _tournamentId = _asInt(json['tournament_id']);
    _count = _asInt(json['count']);

    final list = json['matches'];
    if (list is List) {
      _matches = list
          .whereType<Map<String, dynamic>>()
          .map((item) => TournamentMatchResponse.fromJson(item))
          .toList();
    } else {
      _matches = null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tournament_id': _tournamentId,
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
