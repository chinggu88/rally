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

  PlayerResponse({
    int? rank,
    String? playerName,
    String? countryCode,
  }) {
    _rank = rank;
    _playerName = playerName;
    _countryCode = countryCode;
  }

  int? get rank => _rank;
  set rank(int? value) => _rank = value;

  String? get playerName => _playerName;
  set playerName(String? value) => _playerName = value;

  String? get countryCode => _countryCode;
  set countryCode(String? value) => _countryCode = value;

  PlayerResponse.fromJson(Map<String, dynamic> json) {
    final rankValue = json['rank'];
    if (rankValue is int) {
      _rank = rankValue;
    } else if (rankValue is num) {
      _rank = rankValue.toInt();
    } else if (rankValue is String) {
      _rank = int.tryParse(rankValue);
    } else {
      _rank = null;
    }
    _playerName = json['player_name'] as String?;
    _countryCode = json['country_code'] as String?;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['rank'] = _rank;
    data['player_name'] = _playerName;
    data['country_code'] = _countryCode;
    return data;
  }
}
