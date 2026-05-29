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

  /// 첫 번째 선수의 `bwf_players.id` — 상세 화면(get-player) 진입 키.
  /// 단식은 이 값만, 복식은 [_player2Id]와 함께 채워진다.
  int? _player1Id;

  /// 두 번째 선수의 `bwf_players.id` — 복식에서만 채워진다 (단식은 null).
  int? _player2Id;

  PlayerResponse({
    int? rank,
    String? playerName,
    String? countryCode,
    int? player1Id,
    int? player2Id,
  }) {
    _rank = rank;
    _playerName = playerName;
    _countryCode = countryCode;
    _player1Id = player1Id;
    _player2Id = player2Id;
  }

  int? get rank => _rank;
  set rank(int? value) => _rank = value;

  String? get playerName => _playerName;
  set playerName(String? value) => _playerName = value;

  String? get countryCode => _countryCode;
  set countryCode(String? value) => _countryCode = value;

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
    _player1Id = _asInt(json['player1_id']);
    _player2Id = _asInt(json['player2_id']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['rank'] = _rank;
    data['player_name'] = _playerName;
    data['country_code'] = _countryCode;
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
}
