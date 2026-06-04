import 'active_tournament_response.dart';

/// Edge Function `get-active-tournaments-kr` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "today": "2026-06-04",
///   "count": 3,
///   "tournaments": [ { ... ActiveTournamentResponse ... } ]
/// }
/// ```
class GetActiveTournamentsResponse {
  /// 서버 기준 오늘 날짜 (YYYY-MM-DD)
  String? _today;

  /// 응답에 포함된 대회 수
  int? _count;

  /// 진행중/진행예정 대회 목록 (start_date ASC)
  List<ActiveTournamentResponse>? _tournaments;

  GetActiveTournamentsResponse({
    String? today,
    int? count,
    List<ActiveTournamentResponse>? tournaments,
  }) {
    _today = today;
    _count = count;
    _tournaments = tournaments;
  }

  String? get today => _today;
  int? get count => _count;
  List<ActiveTournamentResponse> get tournaments =>
      _tournaments ?? const <ActiveTournamentResponse>[];

  GetActiveTournamentsResponse.fromJson(Map<String, dynamic> json) {
    _today = json['today'] as String?;
    final c = json['count'];
    if (c is int) {
      _count = c;
    } else if (c is num) {
      _count = c.toInt();
    } else if (c is String) {
      _count = int.tryParse(c);
    } else {
      _count = null;
    }

    final list = json['tournaments'];
    if (list is List) {
      _tournaments = list
          .whereType<Map<String, dynamic>>()
          .map(ActiveTournamentResponse.fromJson)
          .toList();
    } else {
      _tournaments = null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'today': _today,
      'count': _count,
      'tournaments': _tournaments?.map((e) => e.toJson()).toList(),
    };
  }
}
