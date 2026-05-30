import 'tournament_detail_response.dart';

/// Edge Function `get-tournament` 의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// { "tournament": { ... TournamentDetailResponse ... } }
/// ```
/// 미존재 시 서버는 404 + `{ "error": "tournament not found" }` 를 반환한다.
class GetTournamentResponse {
  /// 단건 대회 상세 (없으면 null)
  TournamentDetailResponse? _tournament;

  GetTournamentResponse({TournamentDetailResponse? tournament}) {
    _tournament = tournament;
  }

  TournamentDetailResponse? get tournament => _tournament;
  set tournament(TournamentDetailResponse? value) => _tournament = value;

  GetTournamentResponse.fromJson(Map<String, dynamic> json) {
    final tournamentJson = json['tournament'];
    if (tournamentJson is Map<String, dynamic>) {
      _tournament = TournamentDetailResponse.fromJson(tournamentJson);
    } else if (tournamentJson is Map) {
      _tournament = TournamentDetailResponse.fromJson(
        Map<String, dynamic>.from(tournamentJson),
      );
    } else {
      _tournament = null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tournament': _tournament?.toJson(),
    };
  }
}
