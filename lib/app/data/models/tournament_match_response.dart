/// 대회 경기(매치) 단일 항목 응답 모델
///
/// Edge Function `get-tournament-matches`의 `matches[]` 원소(`bwf_matches` 1행)에
/// 1:1 매핑된다. 서버 값의 실제 타입(문자열/배열/정수)이 유동적일 수 있어
/// 모든 파싱을 방어적으로 처리한다.
class TournamentMatchResponse {
  /// bwf_matches PK
  int? _id;

  /// 대회 ID (BWF tournament id)
  int? _tournamentId;

  /// 대회 코드
  String? _tournamentCode;

  /// 종목명 (예: "Men's Singles", "Women's Doubles")
  String? _eventName;

  /// 경기 유형
  String? _matchType;

  /// 라운드명 (예: "Final", "Semi-final", "Round of 16")
  String? _roundName;

  /// 1팀 선수명 목록 (단식 1명 / 복식 2명)
  List<String>? _team1Names;

  /// 1팀 국가
  String? _team1Country;

  /// 1팀 시드
  String? _team1Seed;

  /// 2팀 선수명 목록
  List<String>? _team2Names;

  /// 2팀 국가
  String? _team2Country;

  /// 2팀 시드
  String? _team2Seed;

  /// 승자 (원본 값 — "1"/"2" 또는 팀/선수명일 수 있음)
  String? _winner;

  /// 스코어 (예: "21-18, 21-15")
  String? _score;

  /// 원본 스코어에서 파싱한 게임별 점수쌍(소스 순서 `[first, second]`).
  /// 방향(어느 쪽이 team1)은 [games] getter에서 승자 기준으로 보정한다.
  List<List<int>> _rawGames = const <List<int>>[];

  /// 경기 상태 (completed, live, scheduled 등)
  String? _matchStatus;

  /// 경기 시각 (ISO datetime 문자열)
  String? _matchTime;

  /// 코트명
  String? _courtName;

  /// 경기 소요 시간(분)
  int? _durationMin;

  TournamentMatchResponse({
    int? id,
    int? tournamentId,
    String? tournamentCode,
    String? eventName,
    String? matchType,
    String? roundName,
    List<String>? team1Names,
    String? team1Country,
    String? team1Seed,
    List<String>? team2Names,
    String? team2Country,
    String? team2Seed,
    String? winner,
    String? score,
    String? matchStatus,
    String? matchTime,
    String? courtName,
    int? durationMin,
  }) {
    _id = id;
    _tournamentId = tournamentId;
    _tournamentCode = tournamentCode;
    _eventName = eventName;
    _matchType = matchType;
    _roundName = roundName;
    _team1Names = team1Names;
    _team1Country = team1Country;
    _team1Seed = team1Seed;
    _team2Names = team2Names;
    _team2Country = team2Country;
    _team2Seed = team2Seed;
    _winner = winner;
    _score = score;
    _matchStatus = matchStatus;
    _matchTime = matchTime;
    _courtName = courtName;
    _durationMin = durationMin;
  }

  int? get id => _id;
  int? get tournamentId => _tournamentId;
  String? get tournamentCode => _tournamentCode;
  String? get eventName => _eventName;
  String? get matchType => _matchType;
  String? get roundName => _roundName;
  List<String>? get team1Names => _team1Names;
  String? get team1Country => _team1Country;
  String? get team1Seed => _team1Seed;
  List<String>? get team2Names => _team2Names;
  String? get team2Country => _team2Country;
  String? get team2Seed => _team2Seed;
  String? get winner => _winner;
  String? get score => _score;
  String? get matchStatus => _matchStatus;
  String? get matchTime => _matchTime;
  String? get courtName => _courtName;
  int? get durationMin => _durationMin;

  /// 1팀 표기 문자열 (예: "Player A / Player B"). 비어있으면 "TBD".
  String get team1Display => _joinNames(_team1Names);

  /// 2팀 표기 문자열. 비어있으면 "TBD".
  String get team2Display => _joinNames(_team2Names);

  /// 경기 시각 DateTime (실패 시 null).
  DateTime? get matchDateTime =>
      _matchTime == null ? null : DateTime.tryParse(_matchTime!);

  /// 경기 종료(완료) 여부 — status 또는 승자/스코어 존재로 판단.
  bool get isCompleted {
    final s = (_matchStatus ?? '').toLowerCase();
    if (s.contains('complete') ||
        s.contains('finish') ||
        s.contains('result') ||
        s.contains('done')) {
      return true;
    }
    return winnerSide != null &&
        _score != null &&
        _score!.trim().isNotEmpty;
  }

  /// 승자 팀 번호 (1 또는 2). 판별 불가 시 null.
  ///
  /// `winner`가 "1"/"2"면 그대로, 아니면 팀 표기 문자열과 대조해 추정한다.
  int? get winnerSide {
    final w = _winner?.trim();
    if (w == null || w.isEmpty) return null;
    if (w == '1') return 1;
    if (w == '2') return 2;

    final lw = w.toLowerCase();
    final t1 = team1Display.toLowerCase();
    final t2 = team2Display.toLowerCase();
    if (t1 != 'tbd' && (t1.contains(lw) || lw.contains(t1))) return 1;
    if (t2 != 'tbd' && (t2.contains(lw) || lw.contains(t2))) return 2;
    return null;
  }

  /// 게임별 스코어 — team1/team2 기준으로 방향이 보정된 목록.
  ///
  /// 원본 스코어는 승자 우선/팀1 우선 등 표기 순서가 불확실하므로,
  /// [winnerSide]와 각 컬럼의 게임 획득 수를 비교해 team1 컬럼을 결정한다.
  /// 파싱 불가하면 빈 목록을 반환한다([scoreDisplay] 폴백 사용).
  List<GameScore> get games {
    if (_rawGames.isEmpty) return const <GameScore>[];

    var team1IsFirst = true;
    final side = winnerSide;
    if (side != null) {
      var firstWins = 0;
      var secondWins = 0;
      for (final p in _rawGames) {
        if (p[0] > p[1]) {
          firstWins += 1;
        } else if (p[1] > p[0]) {
          secondWins += 1;
        }
      }
      // 승자 측이 더 많은 게임을 이겼어야 한다 → 어긋나면 컬럼을 뒤집는다.
      if (side == 1) {
        team1IsFirst = firstWins >= secondWins;
      } else {
        team1IsFirst = firstWins <= secondWins;
      }
    }

    return [
      for (final p in _rawGames)
        team1IsFirst
            ? GameScore(team1: p[0], team2: p[1])
            : GameScore(team1: p[1], team2: p[0]),
    ];
  }

  /// 게임별 스코어 존재 여부
  bool get hasGameScores => _rawGames.isNotEmpty;

  /// 스코어 표시 폴백 문자열 (게임 파싱 실패 시 사용)
  String? get scoreDisplay => _score;

  TournamentMatchResponse.fromJson(Map<String, dynamic> json) {
    _id = _asInt(json['id']);
    _tournamentId = _asInt(json['tournament_id']);
    _tournamentCode = _str(json['tournament_code']);
    _eventName = _str(json['event_name']);
    _matchType = _str(json['match_type']);
    _roundName = _str(json['round_name']);
    _team1Names = _asNameList(json['team1_names']);
    _team1Country = _str(json['team1_country']);
    _team1Seed = _str(json['team1_seed']);
    _team2Names = _asNameList(json['team2_names']);
    _team2Country = _str(json['team2_country']);
    _team2Seed = _str(json['team2_seed']);
    _winner = _str(json['winner']);
    _score = _str(json['score']);
    _rawGames = _parseGames(json['score']);
    _matchStatus = _str(json['match_status']);
    _matchTime = _str(json['match_time']);
    _courtName = _str(json['court_name']);
    _durationMin = _asInt(json['duration_min']);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': _id,
      'tournament_id': _tournamentId,
      'tournament_code': _tournamentCode,
      'event_name': _eventName,
      'match_type': _matchType,
      'round_name': _roundName,
      'team1_names': _team1Names,
      'team1_country': _team1Country,
      'team1_seed': _team1Seed,
      'team2_names': _team2Names,
      'team2_country': _team2Country,
      'team2_seed': _team2Seed,
      'winner': _winner,
      'score': _score,
      'match_status': _matchStatus,
      'match_time': _matchTime,
      'court_name': _courtName,
      'duration_min': _durationMin,
    };
  }

  static String _joinNames(List<String>? names) {
    if (names == null || names.isEmpty) return 'TBD';
    final cleaned = names.map((n) => n.trim()).where((n) => n.isNotEmpty);
    if (cleaned.isEmpty) return 'TBD';
    return cleaned.join(' / ');
  }

  /// 선수명 값을 `List<String>`으로 정규화 — List / 구분자 포함 문자열 / 단일 문자열 모두 허용.
  static List<String>? _asNameList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final list = value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      return list.isEmpty ? null : list;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      // "A / B", "A/B", "A, B" 형태 분리
      final parts = trimmed
          .split(RegExp(r'\s*[/,]\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return parts.isEmpty ? [trimmed] : parts;
    }
    return [value.toString()];
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 스칼라/배열/숫자 값을 표시용 문자열로 정규화한다.
  ///
  /// 서버가 복식 등에서 `team1_country`·`score`를 배열(`List`)로 내려줄 수 있어,
  /// `as String?` 단정 캐스팅 대신 어떤 타입이 와도 크래시 없이 변환한다.
  /// 배열은 원소를 ", "로 join하고, 빈 값은 null로 반환한다.
  static String? _str(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    if (value is List) {
      final parts = value
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    }
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// 원본 스코어 값을 게임별 점수쌍 `[first, second]` 목록으로 파싱한다.
  ///
  /// 허용 형태:
  /// - 문자열 `"21-18, 21-15"` / `"21:18 19-21 21-15"`
  /// - 문자열 배열 `["21-18", "21-15"]`
  /// - 숫자쌍 배열 `[[21,18],[21,15]]`
  /// - 맵 배열 `[{team1:21,team2:18}, ...]`(키: team1/team2, t1/t2, home/away, a/b, 0/1)
  /// 파싱 불가 원소는 건너뛴다.
  static List<List<int>> _parseGames(dynamic value) {
    if (value == null) return const <List<int>>[];

    final games = <List<int>>[];

    void addPair(dynamic a, dynamic b) {
      final x = _asInt(a);
      final y = _asInt(b);
      if (x != null && y != null) games.add(<int>[x, y]);
    }

    List<int>? parseToken(String token) {
      final m = RegExp(r'(\d+)\s*[-:/]\s*(\d+)').firstMatch(token);
      if (m == null) return null;
      final x = int.tryParse(m.group(1)!);
      final y = int.tryParse(m.group(2)!);
      if (x == null || y == null) return null;
      return <int>[x, y];
    }

    if (value is String) {
      // "21-18, 21-15" 또는 공백 구분 "21-18 21-15"
      for (final token in value.split(RegExp(r'\s*,\s*|\s+'))) {
        final pair = parseToken(token);
        if (pair != null) games.add(pair);
      }
    } else if (value is List) {
      for (final e in value) {
        if (e is String) {
          final pair = parseToken(e);
          if (pair != null) games.add(pair);
        } else if (e is List && e.length >= 2) {
          addPair(e[0], e[1]);
        } else if (e is Map) {
          final keys1 = ['team1', 't1', 'home', 'a', 'first', 'left', '0'];
          final keys2 = ['team2', 't2', 'away', 'b', 'second', 'right', '1'];
          dynamic v1, v2;
          for (final k in keys1) {
            if (e.containsKey(k)) {
              v1 = e[k];
              break;
            }
          }
          for (final k in keys2) {
            if (e.containsKey(k)) {
              v2 = e[k];
              break;
            }
          }
          addPair(v1, v2);
        }
      }
    }

    return games;
  }
}

/// 게임 단위 스코어 (team1/team2 기준으로 방향 보정된 점수)
class GameScore {
  const GameScore({required this.team1, required this.team2});

  /// team1 득점
  final int team1;

  /// team2 득점
  final int team2;
}
