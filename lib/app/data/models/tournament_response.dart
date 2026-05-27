/// BWF 국제 대회 단일 항목 응답 모델
///
/// Edge Function `get-tournaments`의 `tournaments[]` 원소에 1:1 매핑된다.
/// 모든 필드는 서버에서 누락될 수 있으므로 nullable로 선언한다.
class TournamentResponse {
  /// 대회 고유 ID (BWF tournament id) — DB: integer not null
  int? _tournamentId;

  /// 대회 공식 명칭
  String? _name;

  /// 투어 등급 (예: BWF World Tour Super 1000)
  String? _tourLevel;

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

  /// 총 상금 (USD) — DB: numeric(12,2), 소수점 포함 가능
  double? _prizeMoneyUsd;

  /// 상세 페이지 외부 URL
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

  TournamentResponse({
    int? tournamentId,
    String? name,
    String? tourLevel,
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
  }) {
    _tournamentId = tournamentId;
    _name = name;
    _tourLevel = tourLevel;
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
  }

  int? get tournamentId => _tournamentId;
  set tournamentId(int? value) => _tournamentId = value;

  String? get name => _name;
  set name(String? value) => _name = value;

  String? get tourLevel => _tourLevel;
  set tourLevel(String? value) => _tourLevel = value;

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

  TournamentResponse.fromJson(Map<String, dynamic> json) {
    final tournamentIdValue = json['tournament_id'];
    if (tournamentIdValue is int) {
      _tournamentId = tournamentIdValue;
    } else if (tournamentIdValue is num) {
      _tournamentId = tournamentIdValue.toInt();
    } else if (tournamentIdValue is String) {
      _tournamentId = int.tryParse(tournamentIdValue);
    } else {
      _tournamentId = null;
    }
    _name = json['name'] as String?;
    _tourLevel = json['tour_level'] as String?;
    _startDate = json['start_date'] as String?;
    _endDate = json['end_date'] as String?;
    _dateLabel = json['date_label'] as String?;
    _country = json['country'] as String?;
    _location = json['location'] as String?;
    final prize = json['prize_money_usd'];
    if (prize is num) {
      _prizeMoneyUsd = prize.toDouble();
    } else if (prize is String) {
      _prizeMoneyUsd = double.tryParse(prize);
    } else {
      _prizeMoneyUsd = null;
    }
    _detailUrl = json['detail_url'] as String?;
    _flagUrl = json['flag_url'] as String?;
    _logoUrl = json['logo_url'] as String?;
    _catLogoUrl = json['cat_logo_url'] as String?;
    _status = json['status'] as String?;
    _hasLiveScores = json['has_live_scores'] as bool?;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['tournament_id'] = _tournamentId;
    data['name'] = _name;
    data['tour_level'] = _tourLevel;
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
    return data;
  }
}
