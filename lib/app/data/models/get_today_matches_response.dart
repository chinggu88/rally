import 'today_match_response.dart';

/// Edge Function `get-today-matches`의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "date": "2026-06-07",
///   "results_count": 12,
///   "upcoming_count": 8,
///   "results":  [ { ... TodayMatchResponse ... } ],
///   "upcoming": [ { ... TodayMatchResponse ... } ]
/// }
/// ```
///
/// 빈 응답(데이터 없음 / 404) 케이스에서도 `results` / `upcoming`은 빈 배열로
/// 보장되도록 fromJson에서 null safe 처리한다.
class GetTodayMatchesResponse {
  /// 응답 기준 날짜 (YYYY-MM-DD, KST 기준)
  String? _date;

  /// results 항목 수
  int? _resultsCount;

  /// upcoming 항목 수
  int? _upcomingCount;

  /// 오늘 경기 결과 목록 (서버에서 reverse 적용 — 최근 끝난 게 먼저)
  List<TodayMatchResponse>? _results;

  /// 오늘 예정 경기 목록 (match_time ASC)
  List<TodayMatchResponse>? _upcoming;

  GetTodayMatchesResponse({
    String? date,
    int? resultsCount,
    int? upcomingCount,
    List<TodayMatchResponse>? results,
    List<TodayMatchResponse>? upcoming,
  }) {
    _date = date;
    _resultsCount = resultsCount;
    _upcomingCount = upcomingCount;
    _results = results;
    _upcoming = upcoming;
  }

  String? get date => _date;
  int? get resultsCount => _resultsCount;
  int? get upcomingCount => _upcomingCount;
  List<TodayMatchResponse>? get results => _results;
  List<TodayMatchResponse>? get upcoming => _upcoming;

  GetTodayMatchesResponse.fromJson(Map<String, dynamic> json) {
    _date = _str(json['date']);
    _resultsCount = _asInt(json['results_count']);
    _upcomingCount = _asInt(json['upcoming_count']);
    _results = _parseList(json['results']);
    _upcoming = _parseList(json['upcoming']);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date': _date,
      'results_count': _resultsCount,
      'upcoming_count': _upcomingCount,
      'results': _results?.map((e) => e.toJson()).toList(),
      'upcoming': _upcoming?.map((e) => e.toJson()).toList(),
    };
  }

  /// 배열 키가 null/비-List/빈 배열이어도 안전하게 빈 리스트로 폴백한다.
  static List<TodayMatchResponse> _parseList(dynamic value) {
    if (value is! List) return const <TodayMatchResponse>[];
    return value
        .whereType<Map>()
        .map((e) => TodayMatchResponse.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final t = value.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }
    return null;
  }

  static String? _str(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    return value.toString();
  }
}
