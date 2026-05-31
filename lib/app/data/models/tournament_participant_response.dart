import '../../utils/bwf_image.dart';

/// 대회 참가자(단일 항목) 응답 모델.
///
/// Edge Function `get-tournament-participants`의 `participants[]` 원소에 1:1
/// 매핑된다. 모든 필드는 서버에서 누락될 수 있으므로 nullable로 선언한다.
///
/// 단식(MS/WS)은 `player1_*`만 채워지고 `player2_*`는 null이다.
/// 복식(MD/WD/XD)은 두 선수 모두 채워진다.
class TournamentParticipantResponse {
  /// 종목 코드 — `MS | WS | MD | WD | XD`
  String? _eventName;

  /// 첫 번째 선수의 `bwf_players.id` (단식/복식 공통, 대표 1인)
  int? _player1Id;

  /// 두 번째 선수의 `bwf_players.id` — 복식에서만 채워짐 (단식은 null)
  int? _player2Id;

  /// 첫 번째 선수 영문 풀네임 (예: "Viktor Axelsen")
  String? _player1Name;

  /// 두 번째 선수 영문 풀네임 — 복식에서만 채워짐
  String? _player2Name;

  /// 국가 3자 코드 (예: "DEN", "KOR", "CHN")
  ///
  /// 복식에서 양 선수의 국가가 다른 경우 player1 기준으로 들어올 수 있다.
  String? _country;

  /// 시드 번호 (1이 최고 시드). 시드가 없는 참가자는 null.
  int? _seed;

  /// 첫 라운드 코드 (예: "R64", "R32", "R16", "QF", "SF", "F")
  String? _firstRound;

  /// 대표(player1) 선수의 프로필 사진 URL — 없으면 null.
  ///
  /// `bwfImageUrl`로 Cloudflare 호스트가 Cloudinary로 치환된다.
  String? _photoUrl;

  TournamentParticipantResponse({
    String? eventName,
    int? player1Id,
    int? player2Id,
    String? player1Name,
    String? player2Name,
    String? country,
    int? seed,
    String? firstRound,
    String? photoUrl,
  }) {
    _eventName = eventName;
    _player1Id = player1Id;
    _player2Id = player2Id;
    _player1Name = player1Name;
    _player2Name = player2Name;
    _country = country;
    _seed = seed;
    _firstRound = firstRound;
    _photoUrl = photoUrl;
  }

  String? get eventName => _eventName;
  set eventName(String? value) => _eventName = value;

  int? get player1Id => _player1Id;
  set player1Id(int? value) => _player1Id = value;

  int? get player2Id => _player2Id;
  set player2Id(int? value) => _player2Id = value;

  String? get player1Name => _player1Name;
  set player1Name(String? value) => _player1Name = value;

  String? get player2Name => _player2Name;
  set player2Name(String? value) => _player2Name = value;

  String? get country => _country;
  set country(String? value) => _country = value;

  int? get seed => _seed;
  set seed(int? value) => _seed = value;

  String? get firstRound => _firstRound;
  set firstRound(String? value) => _firstRound = value;

  String? get photoUrl => _photoUrl;
  set photoUrl(String? value) => _photoUrl = value;

  /// 복식 여부 — `player2_id`가 채워져 있으면 true.
  bool get isDoubles => _player2Id != null;

  /// 카드에 한 줄로 표시할 표기 이름.
  ///
  /// 단식: `player1Name` 그대로.
  /// 복식: `player1Name / player2Name` (이름이 비어있으면 "—"로 폴백).
  String get displayName {
    final p1 = (_player1Name ?? '').trim();
    if (!isDoubles) {
      return p1.isEmpty ? '—' : p1;
    }
    final p2 = (_player2Name ?? '').trim();
    final left = p1.isEmpty ? '—' : p1;
    final right = p2.isEmpty ? '—' : p2;
    return '$left / $right';
  }

  /// 상세 진입에 사용할 대표 식별자 (player1Id 우선, 없으면 player2Id).
  int? get detailId => _player1Id ?? _player2Id;

  TournamentParticipantResponse.fromJson(Map<String, dynamic> json) {
    _eventName = json['event_name'] as String?;
    _player1Id = _asInt(json['player1_id']);
    _player2Id = _asInt(json['player2_id']);
    _player1Name = json['player1_name'] as String?;
    _player2Name = json['player2_name'] as String?;
    _country = json['country'] as String?;
    _seed = _asInt(json['seed']);
    _firstRound = json['first_round'] as String?;
    _photoUrl = bwfImageUrl(json['photo_url'] as String?);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['event_name'] = _eventName;
    data['player1_id'] = _player1Id;
    data['player2_id'] = _player2Id;
    data['player1_name'] = _player1Name;
    data['player2_name'] = _player2Name;
    data['country'] = _country;
    data['seed'] = _seed;
    data['first_round'] = _firstRound;
    data['photo_url'] = _photoUrl;
    return data;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
