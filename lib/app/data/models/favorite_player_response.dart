/// 좋아하는 선수 응답 모델 — `favorite_players` 테이블 1행에 매핑.
///
/// playerId = `bwf_players.id` (선수 상세 진입 키).
/// 이름/국가/사진은 즐겨찾기 추가 시점의 스냅샷이다(서버 조인 불필요).
class FavoritePlayerResponse {
  final int playerId;
  final String? playerName;
  final String? countryCode;
  final String? photoUrl;

  FavoritePlayerResponse({
    required this.playerId,
    this.playerName,
    this.countryCode,
    this.photoUrl,
  });

  FavoritePlayerResponse.fromJson(Map<String, dynamic> json)
      : playerId = _asInt(json['player_id']) ?? 0,
        playerName = json['player_name'] as String?,
        countryCode = json['country_code'] as String?,
        photoUrl = json['photo_url'] as String?;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'player_id': playerId,
        'player_name': playerName,
        'country_code': countryCode,
        'photo_url': photoUrl,
      };

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
