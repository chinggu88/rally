import 'tournament_response.dart';

/// Edge Function `get-tournaments` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "year": 2026,
///   "count": 32,
///   "tournaments": [ { ... TournamentResponse ... } ]
/// }
/// ```
class GetTournamentsResponse {
  /// 조회한 연도
  int? _year;

  /// 응답에 포함된 대회 수
  int? _count;

  /// 대회 목록
  List<TournamentResponse>? _tournaments;

  GetTournamentsResponse({
    int? year,
    int? count,
    List<TournamentResponse>? tournaments,
  }) {
    _year = year;
    _count = count;
    _tournaments = tournaments;
  }

  int? get year => _year;
  set year(int? value) => _year = value;

  int? get count => _count;
  set count(int? value) => _count = value;

  List<TournamentResponse>? get tournaments => _tournaments;
  set tournaments(List<TournamentResponse>? value) => _tournaments = value;

  GetTournamentsResponse.fromJson(Map<String, dynamic> json) {
    final yearValue = json['year'];
    if (yearValue is int) {
      _year = yearValue;
    } else if (yearValue is num) {
      _year = yearValue.toInt();
    } else if (yearValue is String) {
      _year = int.tryParse(yearValue);
    } else {
      _year = null;
    }

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

    final list = json['tournaments'];
    if (list is List) {
      _tournaments = list
          .whereType<Map<String, dynamic>>()
          .map((item) => TournamentResponse.fromJson(item))
          .toList();
    } else {
      _tournaments = null;
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['year'] = _year;
    data['count'] = _count;
    data['tournaments'] =
        _tournaments?.map((item) => item.toJson()).toList();
    return data;
  }
}
