import '../../utils/bwf_image.dart';

/// `get-active-tournaments-kr` 응답의 `tournaments[]` 단일 항목.
///
/// 오늘 날짜를 포함해 진행중/진행예정인 대회 + 한국 선수 참여 정보를 담는다.
/// 모든 필드는 서버에서 누락될 수 있으므로 nullable로 선언한다.
class ActiveTournamentResponse {
  /// 대회 고유 ID (BWF tournament id)
  int? _tournamentId;

  /// 개최 국가 코드 또는 국가명 (필수 표시 필드)
  String? _country;

  /// 대회 공식 명칭 (필수 표시 필드)
  String? _name;

  /// 점수 — BWF World Tour 우승자 기준 랭킹 포인트 (매핑 불가 시 null)
  int? _points;

  /// 대회 시작일 (YYYY-MM-DD) — 날짜 필드
  String? _startDate;

  /// 대회 종료일 (YYYY-MM-DD) — 날짜 필드
  String? _endDate;

  /// 사용자 노출용 기간 라벨 (예: "Jan 9–14")
  String? _dateLabel;

  /// 한국 선수 참여 인원 (필수 표시 필드)
  int? _koreanPlayerCount;

  /// 대회 진행 상태 (ongoing | upcoming | unknown)
  String? _status;

  /// 투어 등급 (예: SUPER_1000, Super 100 등)
  String? _tourLevel;

  /// 개최 도시/장소
  String? _location;

  /// 총 상금 (USD)
  double? _prizeMoneyUsd;

  /// 라이브 스코어 제공 여부
  bool? _hasLiveScores;

  /// 참가 선수 총원 (고유 선수 수)
  int? _participantCount;

  /// 한국 선수 목록 (id/이름)
  List<KoreanPlayerSummary>? _koreanPlayers;

  /// 국가 국기 이미지 URL
  String? _flagUrl;

  /// 대회 로고 이미지 URL
  String? _logoUrl;

  /// 카테고리 로고 이미지 URL
  String? _catLogoUrl;

  ActiveTournamentResponse({
    int? tournamentId,
    String? country,
    String? name,
    int? points,
    String? startDate,
    String? endDate,
    String? dateLabel,
    int? koreanPlayerCount,
    String? status,
    String? tourLevel,
    String? location,
    double? prizeMoneyUsd,
    bool? hasLiveScores,
    int? participantCount,
    List<KoreanPlayerSummary>? koreanPlayers,
    String? flagUrl,
    String? logoUrl,
    String? catLogoUrl,
  }) {
    _tournamentId = tournamentId;
    _country = country;
    _name = name;
    _points = points;
    _startDate = startDate;
    _endDate = endDate;
    _dateLabel = dateLabel;
    _koreanPlayerCount = koreanPlayerCount;
    _status = status;
    _tourLevel = tourLevel;
    _location = location;
    _prizeMoneyUsd = prizeMoneyUsd;
    _hasLiveScores = hasLiveScores;
    _participantCount = participantCount;
    _koreanPlayers = koreanPlayers;
    _flagUrl = flagUrl;
    _logoUrl = logoUrl;
    _catLogoUrl = catLogoUrl;
  }

  int? get tournamentId => _tournamentId;
  String? get country => _country;
  String? get name => _name;
  int? get points => _points;
  String? get startDate => _startDate;
  String? get endDate => _endDate;
  String? get dateLabel => _dateLabel;
  int? get koreanPlayerCount => _koreanPlayerCount;
  String? get status => _status;
  String? get tourLevel => _tourLevel;
  String? get location => _location;
  double? get prizeMoneyUsd => _prizeMoneyUsd;
  bool? get hasLiveScores => _hasLiveScores;
  int? get participantCount => _participantCount;
  List<KoreanPlayerSummary> get koreanPlayers =>
      _koreanPlayers ?? const <KoreanPlayerSummary>[];
  String? get flagUrl => _flagUrl;
  String? get logoUrl => _logoUrl;
  String? get catLogoUrl => _catLogoUrl;

  /// 진행중 여부 (status 우선, 없으면 날짜로 판단).
  bool get isOngoing {
    final s = _status?.toLowerCase();
    if (s == 'ongoing') return true;
    if (s == 'upcoming') return false;
    final start = startDateTime;
    final end = endDateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (start == null && end == null) return false;
    if (start != null && today.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null && today.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  /// 한국 선수가 1명 이상 참여하는지 여부.
  bool get hasKoreans => (_koreanPlayerCount ?? 0) > 0;

  DateTime? get startDateTime =>
      _startDate == null ? null : DateTime.tryParse(_startDate!);
  DateTime? get endDateTime =>
      _endDate == null ? null : DateTime.tryParse(_endDate!);

  ActiveTournamentResponse.fromJson(Map<String, dynamic> json) {
    _tournamentId = _asInt(json['tournament_id']);
    _country = json['country'] as String?;
    _name = json['name'] as String?;
    _points = _asInt(json['points']);
    _startDate = json['start_date'] as String?;
    _endDate = json['end_date'] as String?;
    _dateLabel = json['date_label'] as String?;
    _koreanPlayerCount = _asInt(json['korean_player_count']);
    _status = json['status'] as String?;
    _tourLevel = json['tour_level'] as String?;
    _location = json['location'] as String?;
    final prize = json['prize_money_usd'];
    if (prize is num) {
      _prizeMoneyUsd = prize.toDouble();
    } else if (prize is String) {
      _prizeMoneyUsd = double.tryParse(prize);
    } else {
      _prizeMoneyUsd = null;
    }
    _hasLiveScores = json['has_live_scores'] as bool?;
    _participantCount = _asInt(json['participant_count']);
    final players = json['korean_players'];
    if (players is List) {
      _koreanPlayers = players
          .whereType<Map<String, dynamic>>()
          .map(KoreanPlayerSummary.fromJson)
          .toList();
    } else {
      _koreanPlayers = null;
    }
    _flagUrl = bwfImageUrl(json['flag_url'] as String?);
    _logoUrl = bwfImageUrl(json['logo_url'] as String?);
    _catLogoUrl = bwfImageUrl(json['cat_logo_url'] as String?);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tournament_id': _tournamentId,
      'country': _country,
      'name': _name,
      'points': _points,
      'start_date': _startDate,
      'end_date': _endDate,
      'date_label': _dateLabel,
      'korean_player_count': _koreanPlayerCount,
      'status': _status,
      'tour_level': _tourLevel,
      'location': _location,
      'prize_money_usd': _prizeMoneyUsd,
      'has_live_scores': _hasLiveScores,
      'participant_count': _participantCount,
      'korean_players': _koreanPlayers?.map((e) => e.toJson()).toList(),
      'flag_url': _flagUrl,
      'logo_url': _logoUrl,
      'cat_logo_url': _catLogoUrl,
    };
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 대회에 참가한 한국 선수 요약 (id + 이름).
class KoreanPlayerSummary {
  int? _playerId;
  String? _name;

  KoreanPlayerSummary({int? playerId, String? name}) {
    _playerId = playerId;
    _name = name;
  }

  int? get playerId => _playerId;
  String? get name => _name;

  KoreanPlayerSummary.fromJson(Map<String, dynamic> json) {
    final id = json['player_id'];
    if (id is int) {
      _playerId = id;
    } else if (id is num) {
      _playerId = id.toInt();
    } else if (id is String) {
      _playerId = int.tryParse(id);
    } else {
      _playerId = null;
    }
    _name = json['name'] as String?;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'player_id': _playerId, 'name': _name};
  }
}
