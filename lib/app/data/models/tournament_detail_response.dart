import '../../utils/bwf_image.dart';

/// 대회 진행 단계 — 상세 화면의 3가지 상태(경기 전/중/완료)를 구분한다.
enum TournamentPhase {
  /// 경기 전 (개막 예정)
  before,

  /// 경기 중 (대회 진행 / 라이브)
  live,

  /// 경기 완료 (종료)
  completed,
}

/// 대회 상세 응답 모델
///
/// Edge Function `get-tournament`가 반환하는 `tournament` 객체
/// (`bwf_tournaments` 테이블 1행)에 1:1 매핑된다. PK(`id`)·`tournament_id`·
/// `name`을 제외하면 서버에서 누락될 수 있으므로 모두 nullable로 선언한다.
class TournamentDetailResponse {
  /// bwf_tournaments PK (bigint)
  int? _id;

  /// 대회 고유 ID (BWF tournament id) — DB: integer not null
  int? _tournamentId;

  /// 대회 코드
  String? _code;

  /// 대회 공식 명칭
  String? _name;

  /// 투어 등급 (예: SUPER_1000)
  String? _tourLevel;

  /// 카테고리 ID
  int? _categoryId;

  /// 대회 시작일 (YYYY-MM-DD)
  String? _startDate;

  /// 대회 종료일 (YYYY-MM-DD)
  String? _endDate;

  /// 사용자 노출용 기간 라벨 (예: "Jan 9–14")
  String? _dateLabel;

  /// 개최 국가 코드 또는 국가명
  String? _country;

  /// 개최 도시/장소
  String? _location;

  /// 총 상금 (USD) — DB: numeric(12,2)
  double? _prizeMoneyUsd;

  /// 상세 페이지 외부 URL (BWF 공식)
  String? _detailUrl;

  /// 국가 국기 이미지 URL
  String? _flagUrl;

  /// 대회 로고 이미지 URL
  String? _logoUrl;

  /// 카테고리 로고 이미지 URL (BWF World Tour 등급 로고)
  String? _catLogoUrl;

  /// 대회 진행 상태 (upcoming, ongoing, completed 등)
  String? _status;

  /// 라이브 스코어 제공 여부
  bool? _hasLiveScores;

  /// 시즌 연도
  int? _year;

  /// 원본 크롤 데이터 (jsonb)
  Map<String, dynamic>? _raw;

  /// 레코드 크롤 시각 (ISO datetime 문자열)
  String? _crawledAt;

  TournamentDetailResponse({
    int? id,
    int? tournamentId,
    String? code,
    String? name,
    String? tourLevel,
    int? categoryId,
    String? startDate,
    String? endDate,
    String? dateLabel,
    String? country,
    String? location,
    double? prizeMoneyUsd,
    String? detailUrl,
    String? flagUrl,
    String? logoUrl,
    String? catLogoUrl,
    String? status,
    bool? hasLiveScores,
    int? year,
    Map<String, dynamic>? raw,
    String? crawledAt,
  }) {
    _id = id;
    _tournamentId = tournamentId;
    _code = code;
    _name = name;
    _tourLevel = tourLevel;
    _categoryId = categoryId;
    _startDate = startDate;
    _endDate = endDate;
    _dateLabel = dateLabel;
    _country = country;
    _location = location;
    _prizeMoneyUsd = prizeMoneyUsd;
    _detailUrl = detailUrl;
    _flagUrl = flagUrl;
    _logoUrl = logoUrl;
    _catLogoUrl = catLogoUrl;
    _status = status;
    _hasLiveScores = hasLiveScores;
    _year = year;
    _raw = raw;
    _crawledAt = crawledAt;
  }

  int? get id => _id;
  set id(int? value) => _id = value;

  int? get tournamentId => _tournamentId;
  set tournamentId(int? value) => _tournamentId = value;

  String? get code => _code;
  set code(String? value) => _code = value;

  String? get name => _name;
  set name(String? value) => _name = value;

  String? get tourLevel => _tourLevel;
  set tourLevel(String? value) => _tourLevel = value;

  int? get categoryId => _categoryId;
  set categoryId(int? value) => _categoryId = value;

  String? get startDate => _startDate;
  set startDate(String? value) => _startDate = value;

  String? get endDate => _endDate;
  set endDate(String? value) => _endDate = value;

  String? get dateLabel => _dateLabel;
  set dateLabel(String? value) => _dateLabel = value;

  String? get country => _country;
  set country(String? value) => _country = value;

  String? get location => _location;
  set location(String? value) => _location = value;

  double? get prizeMoneyUsd => _prizeMoneyUsd;
  set prizeMoneyUsd(double? value) => _prizeMoneyUsd = value;

  String? get detailUrl => _detailUrl;
  set detailUrl(String? value) => _detailUrl = value;

  String? get flagUrl => _flagUrl;
  set flagUrl(String? value) => _flagUrl = value;

  String? get logoUrl => _logoUrl;
  set logoUrl(String? value) => _logoUrl = value;

  String? get catLogoUrl => _catLogoUrl;
  set catLogoUrl(String? value) => _catLogoUrl = value;

  String? get status => _status;
  set status(String? value) => _status = value;

  bool? get hasLiveScores => _hasLiveScores;
  set hasLiveScores(bool? value) => _hasLiveScores = value;

  int? get year => _year;
  set year(int? value) => _year = value;

  Map<String, dynamic>? get raw => _raw;
  set raw(Map<String, dynamic>? value) => _raw = value;

  String? get crawledAt => _crawledAt;
  set crawledAt(String? value) => _crawledAt = value;

  /// 시작일 문자열을 DateTime으로 파싱 (실패 시 null).
  DateTime? get startDateTime =>
      _startDate == null ? null : DateTime.tryParse(_startDate!);

  /// 종료일 문자열을 DateTime으로 파싱 (실패 시 null).
  DateTime? get endDateTime =>
      _endDate == null ? null : DateTime.tryParse(_endDate!);

  TournamentDetailResponse.fromJson(Map<String, dynamic> json) {
    _id = _asInt(json['id']);
    _tournamentId = _asInt(json['tournament_id']);
    _code = json['code'] as String?;
    _name = json['name'] as String?;
    _tourLevel = json['tour_level'] as String?;
    _categoryId = _asInt(json['category_id']);
    _startDate = json['start_date'] as String?;
    _endDate = json['end_date'] as String?;
    _dateLabel = json['date_label'] as String?;
    _country = json['country'] as String?;
    _location = json['location'] as String?;
    _prizeMoneyUsd = _asDouble(json['prize_money_usd']);
    _detailUrl = json['detail_url'] as String?;
    _flagUrl = bwfImageUrl(json['flag_url'] as String?);
    _logoUrl = bwfImageUrl(json['logo_url'] as String?);
    _catLogoUrl = bwfImageUrl(json['cat_logo_url'] as String?);
    _status = json['status'] as String?;
    _hasLiveScores = json['has_live_scores'] as bool?;
    _year = _asInt(json['year']);
    _raw = _asMap(json['raw']);
    _crawledAt = json['crawled_at'] as String?;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = _id;
    data['tournament_id'] = _tournamentId;
    data['code'] = _code;
    data['name'] = _name;
    data['tour_level'] = _tourLevel;
    data['category_id'] = _categoryId;
    data['start_date'] = _startDate;
    data['end_date'] = _endDate;
    data['date_label'] = _dateLabel;
    data['country'] = _country;
    data['location'] = _location;
    data['prize_money_usd'] = _prizeMoneyUsd;
    data['detail_url'] = _detailUrl;
    data['flag_url'] = _flagUrl;
    data['logo_url'] = _logoUrl;
    data['cat_logo_url'] = _catLogoUrl;
    data['status'] = _status;
    data['has_live_scores'] = _hasLiveScores;
    data['year'] = _year;
    data['raw'] = _raw;
    data['crawled_at'] = _crawledAt;
    return data;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
