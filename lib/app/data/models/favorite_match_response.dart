/// 관심 경기 응답 모델 — `favorite_matches` 테이블 1행에 매핑.
///
/// 논리 키는 [matchCode]다. `bwf_matches.id`와 `bwf_live_matches.id`는 서로 다른
/// 테이블의 PK라 라이브 전환 시 이어지지 않는다. [matchId]는 참고용이다.
///
/// 스코어/상태는 관심 지정 및 갱신 시점의 스냅샷이며 홈스크린 위젯 렌더용이다.
class FavoriteMatchResponse {
  final String matchCode;
  final int? matchId;

  final String? tournamentName;
  final String? roundName;
  final String? eventName;
  final String? courtName;

  final String? team1Name;
  final String? team1Country;
  final String? team2Name;
  final String? team2Country;

  final String? score;
  final String? matchStatus;
  final String? matchTimeKst;
  final bool isLive;

  FavoriteMatchResponse({
    required this.matchCode,
    this.matchId,
    this.tournamentName,
    this.roundName,
    this.eventName,
    this.courtName,
    this.team1Name,
    this.team1Country,
    this.team2Name,
    this.team2Country,
    this.score,
    this.matchStatus,
    this.matchTimeKst,
    this.isLive = false,
  });

  FavoriteMatchResponse.fromJson(Map<String, dynamic> json)
      : matchCode = (json['match_code'] as String?) ?? '',
        matchId = _asInt(json['match_id']),
        tournamentName = json['tournament_name'] as String?,
        roundName = json['round_name'] as String?,
        eventName = json['event_name'] as String?,
        courtName = json['court_name'] as String?,
        team1Name = json['team1_name'] as String?,
        team1Country = json['team1_country'] as String?,
        team2Name = json['team2_name'] as String?,
        team2Country = json['team2_country'] as String?,
        score = json['score'] as String?,
        matchStatus = json['match_status'] as String?,
        matchTimeKst = json['match_time_kst'] as String?,
        isLive = json['is_live'] == true;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'match_code': matchCode,
        'match_id': matchId,
        'tournament_name': tournamentName,
        'round_name': roundName,
        'event_name': eventName,
        'court_name': courtName,
        'team1_name': team1Name,
        'team1_country': team1Country,
        'team2_name': team2Name,
        'team2_country': team2Country,
        'score': score,
        'match_status': matchStatus,
        'match_time_kst': matchTimeKst,
        'is_live': isLive,
      };

  /// 스냅샷 일부만 바꾼 사본 (Realtime 스코어 갱신용).
  FavoriteMatchResponse copyWith({
    String? score,
    String? matchStatus,
    bool? isLive,
  }) {
    return FavoriteMatchResponse(
      matchCode: matchCode,
      matchId: matchId,
      tournamentName: tournamentName,
      roundName: roundName,
      eventName: eventName,
      courtName: courtName,
      team1Name: team1Name,
      team1Country: team1Country,
      team2Name: team2Name,
      team2Country: team2Country,
      score: score ?? this.score,
      matchStatus: matchStatus ?? this.matchStatus,
      matchTimeKst: matchTimeKst,
      isLive: isLive ?? this.isLive,
    );
  }

  // ── UI 편의 getters ─────────────────────────────────────────

  /// 게임별 점수쌍 `[first, second]` 목록.
  List<List<int>> get games => _parseGames(score);

  /// 경기가 끝났는지 여부 (match_status 기준).
  ///
  /// bwf 데이터는 종료를 'F'(Finished) 또는 'completed'로 표기한다.
  bool get isFinished {
    final s = (matchStatus ?? '').trim().toUpperCase();
    return s == 'F' || s.contains('COMPLET') || s.contains('FINISH');
  }

  // ── 위젯 브리지 계약 ────────────────────────────────────────

  /// 네이티브(Swift/Kotlin)가 읽는 JSON. **스키마 변경 시 양쪽 동기화 필요.**
  ///
  /// 위젯은 이 한 덩어리만 읽으므로, 계약은 반드시 여기 한 곳에만 존재한다.
  Map<String, dynamic> toWidgetJson() {
    final g = games;
    final meta = <String>[
      for (final p in [courtName, roundName, eventName])
        if (p != null && p.trim().isNotEmpty) p.trim(),
    ].join(' · ');

    // 마지막 게임이 현재(또는 최종) 스코어. 없으면 0-0.
    final current = g.isEmpty ? <int>[0, 0] : g.last;

    // 이전 세트 칩 — 마지막 게임을 제외한 나머지.
    final prev = <Map<String, dynamic>>[
      for (var i = 0; i < g.length - 1; i++)
        {'text': '${g[i][0]}–${g[i][1]}', 'won': g[i][0] > g[i][1]},
    ];

    return <String, dynamic>{
      'tournament': tournamentName ?? '',
      'meta': meta,
      'team1': team1Name ?? 'TBD',
      'team1Country': (team1Country ?? '').toUpperCase(),
      'team2': team2Name ?? 'TBD',
      'team2Country': (team2Country ?? '').toUpperCase(),
      'current': current,
      'setLabel': g.isEmpty ? '' : '${g.length}세트',
      'prevSets': prev,
      'isLive': isLive,
      'timeKst': matchTimeKst ?? '',
    };
  }

  // ── helpers ────────────────────────────────────────────────

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// 원본 스코어 문자열을 게임별 점수쌍 목록으로 파싱한다.
  ///
  /// 허용 형태: "21-18, 21-15" / "21:18 19-21 21-15".
  /// (`TodayMatchResponse._parseGames`의 문자열 경로와 동일 규칙.)
  static List<List<int>> _parseGames(String? value) {
    if (value == null) return const <List<int>>[];
    final games = <List<int>>[];
    for (final token in value.split(RegExp(r'\s*,\s*|\s+'))) {
      final m = RegExp(r'(\d+)\s*[-:/]\s*(\d+)').firstMatch(token);
      if (m == null) continue;
      final x = int.tryParse(m.group(1)!);
      final y = int.tryParse(m.group(2)!);
      if (x != null && y != null) games.add(<int>[x, y]);
    }
    return games;
  }
}
