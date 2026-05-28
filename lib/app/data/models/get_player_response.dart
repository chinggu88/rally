import 'player_detail_response.dart';

/// Edge Function `get-player` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// { "player": { ... PlayerDetailResponse ... } }
/// ```
/// 미존재 시 서버는 404 + `{ "error": "player not found" }` 를 반환한다.
class GetPlayerResponse {
  /// 단건 선수 상세 (없으면 null)
  PlayerDetailResponse? _player;

  GetPlayerResponse({PlayerDetailResponse? player}) {
    _player = player;
  }

  PlayerDetailResponse? get player => _player;
  set player(PlayerDetailResponse? value) => _player = value;

  GetPlayerResponse.fromJson(Map<String, dynamic> json) {
    final playerJson = json['player'];
    if (playerJson is Map<String, dynamic>) {
      _player = PlayerDetailResponse.fromJson(playerJson);
    } else if (playerJson is Map) {
      _player = PlayerDetailResponse.fromJson(
        Map<String, dynamic>.from(playerJson),
      );
    } else {
      _player = null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'player': _player?.toJson(),
    };
  }
}
