import '../../utils/bwf_image.dart';

/// BWF 랭킹 선수 단일 항목 응답 모델
///
/// Edge Function `get-players`의 `players[]` 원소에 1:1 매핑된다.
/// 모든 필드는 서버에서 누락될 수 있으므로 nullable로 선언한다.
class PlayerResponse {
  /// 세계 랭킹 (1부터 시작) — DB: integer
  int? _rank;

  /// 선수 영문 풀네임 (예: "Viktor Axelsen")
  String? _playerName;

  /// 국가 3자 코드 (예: "DEN", "KOR", "CHN")
  String? _countryCode;

  /// 국가 표기명 (예: "Korea", "Denmark") — 없으면 null.
  String? _countryName;

  /// 대표 선수(player1) 프로필 사진 URL — 없으면 null.
  String? _photoUrl;

  /// 복식 파트너(player2) 프로필 사진 URL — 단식은 항상 null.
  String? _photoUrl2;

  /// 랭킹 포인트 — DB: numeric(10,2). 없으면 null.
  double? _points;

  /// 직전 발표 대비 순위 변동 — DB: int (nullable).
  /// 양수 = 상승(초록), 음수 = 하락(빨강), 0 = 변동 없음, null = 신규/미상.
  int? _rankChange;

  /// 첫 번째 선수의 `bwf_players.id` — 상세 화면(get-player) 진입 키.
  /// 단식은 이 값만, 복식은 [_player2Id]와 함께 채워진다.
  int? _player1Id;

  /// 두 번째 선수의 `bwf_players.id` — 복식에서만 채워진다 (단식은 null).
  int? _player2Id;

  PlayerResponse({
    int? rank,
    String? playerName,
    String? countryCode,
    String? countryName,
    String? photoUrl,
    String? photoUrl2,
    double? points,
    int? rankChange,
    int? player1Id,
    int? player2Id,
  }) {
    _rank = rank;
    _playerName = playerName;
    _countryCode = countryCode;
    _countryName = countryName;
    _photoUrl = photoUrl;
    _photoUrl2 = photoUrl2;
    _points = points;
    _rankChange = rankChange;
    _player1Id = player1Id;
    _player2Id = player2Id;
  }

  int? get rank => _rank;
  set rank(int? value) => _rank = value;

  String? get playerName => _playerName;
  set playerName(String? value) => _playerName = value;

  String? get countryCode => _countryCode;
  set countryCode(String? value) => _countryCode = value;

  String? get countryName => _countryName;
  set countryName(String? value) => _countryName = value;

  String? get photoUrl => _photoUrl;
  set photoUrl(String? value) => _photoUrl = value;

  String? get photoUrl2 => _photoUrl2;
  set photoUrl2(String? value) => _photoUrl2 = value;

  double? get points => _points;
  set points(double? value) => _points = value;

  int? get rankChange => _rankChange;
  set rankChange(int? value) => _rankChange = value;

  /// 순위 상승 여부 (rank_change > 0)
  bool get isRankUp => _rankChange != null && _rankChange! > 0;

  /// 순위 하락 여부 (rank_change < 0)
  bool get isRankDown => _rankChange != null && _rankChange! < 0;

  /// 변동 없음 여부 (rank_change == 0)
  bool get isRankSame => _rankChange == 0;

  int? get player1Id => _player1Id;
  set player1Id(int? value) => _player1Id = value;

  int? get player2Id => _player2Id;
  set player2Id(int? value) => _player2Id = value;

  /// 상세 진입에 사용할 대표 식별자 (player1Id 우선, 없으면 player2Id).
  int? get detailId => _player1Id ?? _player2Id;

  PlayerResponse.fromJson(Map<String, dynamic> json) {
    _rank = _asInt(json['rank']);
    _playerName = json['player_name'] as String?;
    _countryCode = json['country_code'] as String?;
    _countryName = json['country_name'] as String?;
    _photoUrl = bwfImageUrl(json['photo_url'] as String?);
    _photoUrl2 = bwfImageUrl(json['photo_url2'] as String?);
    _points = _asDouble(json['points']);
    _rankChange = _asInt(json['rank_change']);
    _player1Id = _asInt(json['player1_id']);
    _player2Id = _asInt(json['player2_id']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['rank'] = _rank;
    data['player_name'] = _playerName;
    data['country_code'] = _countryCode;
    data['country_name'] = _countryName;
    data['photo_url'] = _photoUrl;
    data['photo_url2'] = _photoUrl2;
    data['points'] = _points;
    data['rank_change'] = _rankChange;
    data['player1_id'] = _player1Id;
    data['player2_id'] = _player2Id;
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
}
