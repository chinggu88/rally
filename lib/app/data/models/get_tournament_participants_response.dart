import 'tournament_participant_response.dart';

/// Edge Function `get-tournament-participants`의 최상위 응답 래퍼.
///
/// 응답 예시:
/// ```json
/// {
///   "tournament_id": 123,
///   "event_name": "MS",
///   "count": 32,
///   "participants": [ { ... TournamentParticipantResponse ... } ]
/// }
/// ```
class GetTournamentParticipantsResponse {
  /// 조회한 대회의 `bwf_tournaments.tournament_id`
  int? _tournamentId;

  /// 조회한 종목 코드 (MS/WS/MD/WD/XD)
  String? _eventName;

  /// 응답에 포함된 참가자 수 (`participants.length`와 동일)
  int? _count;

  /// 참가자 목록 (서버에서 seed ASC → player1_name ASC 로 정렬됨)
  List<TournamentParticipantResponse>? _participants;

  GetTournamentParticipantsResponse({
    int? tournamentId,
    String? eventName,
    int? count,
    List<TournamentParticipantResponse>? participants,
  }) {
    _tournamentId = tournamentId;
    _eventName = eventName;
    _count = count;
    _participants = participants;
  }

  int? get tournamentId => _tournamentId;
  set tournamentId(int? value) => _tournamentId = value;

  String? get eventName => _eventName;
  set eventName(String? value) => _eventName = value;

  int? get count => _count;
  set count(int? value) => _count = value;

  List<TournamentParticipantResponse>? get participants => _participants;
  set participants(List<TournamentParticipantResponse>? value) =>
      _participants = value;

  GetTournamentParticipantsResponse.fromJson(Map<String, dynamic> json) {
    _tournamentId = _asInt(json['tournament_id']);
    _eventName = json['event_name'] as String?;
    _count = _asInt(json['count']);

    final list = json['participants'];
    if (list is List) {
      _participants = list
          .whereType<Map<String, dynamic>>()
          .map((item) => TournamentParticipantResponse.fromJson(item))
          .toList();
    } else {
      _participants = null;
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['tournament_id'] = _tournamentId;
    data['event_name'] = _eventName;
    data['count'] = _count;
    data['participants'] =
        _participants?.map((item) => item.toJson()).toList();
    return data;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
