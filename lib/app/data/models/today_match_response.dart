import 'live_match_response.dart';

/// 오늘 경기(매치) 단일 항목 응답 모델.
///
/// Edge Function `get-today-matches`의 `results[]` / `upcoming[]` 원소
/// (=`bwf_matches` 1행에 대회 비정규화 컬럼이 인라인된 형태)에 1:1 매핑된다.
/// 클라이언트는 별도 JOIN 없이 매거진 카드를 그릴 수 있다.
///
/// 서버 값의 실제 타입(문자열/배열/정수)이 유동적일 수 있어 모든 파싱을
/// 방어적으로 처리한다([LiveMatchResponse]와 동일 패턴).
///
/// 게임 단위 점수는 [LiveMatchResponse]의 [LiveGameScore]를 재사용한다.
class TodayMatchResponse {
  // ── 매치 기본 ───────────────────────────────────────────────
  /// bwf_matches PK
  int? _id;

  /// 매치 코드 (예: "MS1-R32-MATCH-01")
  String? _matchCode;

  /// 대회 ID (BWF tournament id)
  int? _tournamentId;

  /// 대회 코드
  String? _tournamentCode;

  /// 대회 상태 (예: 'upcoming' | 'live' | 'completed')
  String? _tournamentStatus;

  /// 종목명 (예: "MS", "Men's Singles" 등 — 표기 유동적)
  String? _eventName;

  /// 경기 유형 (예: "Singles", "Doubles")
  String? _matchType;

  /// 라운드명 (예: "Final", "Semi-final", "Round of 16")
  String? _roundName;

  // ── team1 ──────────────────────────────────────────────────
  List<String>? _team1Names;
  String? _team1Country;
  String? _team1Seed;
  List<int>? _team1PlayerIds;

  // ── team2 ──────────────────────────────────────────────────
  List<String>? _team2Names;
  String? _team2Country;
  String? _team2Seed;
  List<int>? _team2PlayerIds;

  // ── 결과 / 진행 ────────────────────────────────────────────
  /// 승자 (int: 1 또는 2). 미확정이면 null.
  int? _winner;

  /// 원본 스코어 (raw) — 표시·재파싱용으로 String?로 정규화 보관.
  String? _score;

  /// 원본 스코어에서 파싱한 게임별 점수쌍(소스 순서 `[first, second]`).
  /// 방향(어느 쪽이 team1)은 [games] getter에서 승자 기준으로 보정한다.
  List<List<int>> _rawGames = const <List<int>>[];

  /// 경기 상태 (예: 'scheduled' | 'live' | 'completed' — 표기 유동적)
  String? _matchStatus;

  /// 경기 상태 표시값
  String? _matchStatusValue;

  /// 스코어 상태 (예: 'walkover' | 'retired' | null)
  String? _scoreStatus;

  /// 스코어 상태 표시값
  String? _scoreStatusValue;

  // ── 일정 ───────────────────────────────────────────────────
  /// 경기 시각 (서버 로컬/대회 시간 ISO)
  String? _matchTime;

  /// 경기 시각 UTC ISO
  String? _matchTimeUtc;

  /// 경기 시각 KST ISO (예: "2026-06-07T14:30:00+09:00")
  String? _matchTimeKst;

  /// 경기 시각 KST 시·분 (예: "14:30") — 서버 사전계산 값.
  ///
  /// 디바이스/서버 타임존과 무관하게 정확한 한국 시각을 보장한다.
  String? _matchTimeKstHhmm;

  /// 코트명
  String? _courtName;

  /// 경기 장소(아레나)
  String? _locationName;

  /// 경기 소요 시간(분)
  int? _durationMin;

  // ── 대회 비정규화 ───────────────────────────────────────────
  String? _tournamentName;
  String? _tournamentLogoUrl;
  String? _tournamentCatLogoUrl;
  String? _tournamentTourLevel;
  int? _tournamentPrizeMoneyUsd;
  String? _tournamentCountry;
  String? _tournamentFlagUrl;
  String? _tournamentDateLabel;

  TodayMatchResponse({
    int? id,
    String? matchCode,
    int? tournamentId,
    String? tournamentCode,
    String? tournamentStatus,
    String? eventName,
    String? matchType,
    String? roundName,
    List<String>? team1Names,
    String? team1Country,
    String? team1Seed,
    List<int>? team1PlayerIds,
    List<String>? team2Names,
    String? team2Country,
    String? team2Seed,
    List<int>? team2PlayerIds,
    int? winner,
    String? score,
    String? matchStatus,
    String? matchStatusValue,
    String? scoreStatus,
    String? scoreStatusValue,
    String? matchTime,
    String? matchTimeUtc,
    String? matchTimeKst,
    String? matchTimeKstHhmm,
    String? courtName,
    String? locationName,
    int? durationMin,
    String? tournamentName,
    String? tournamentLogoUrl,
    String? tournamentCatLogoUrl,
    String? tournamentTourLevel,
    int? tournamentPrizeMoneyUsd,
    String? tournamentCountry,
    String? tournamentFlagUrl,
    String? tournamentDateLabel,
  }) {
    _id = id;
    _matchCode = matchCode;
    _tournamentId = tournamentId;
    _tournamentCode = tournamentCode;
    _tournamentStatus = tournamentStatus;
    _eventName = eventName;
    _matchType = matchType;
    _roundName = roundName;
    _team1Names = team1Names;
    _team1Country = team1Country;
    _team1Seed = team1Seed;
    _team1PlayerIds = team1PlayerIds;
    _team2Names = team2Names;
    _team2Country = team2Country;
    _team2Seed = team2Seed;
    _team2PlayerIds = team2PlayerIds;
    _winner = winner;
    _score = score;
    _matchStatus = matchStatus;
    _matchStatusValue = matchStatusValue;
    _scoreStatus = scoreStatus;
    _scoreStatusValue = scoreStatusValue;
    _matchTime = matchTime;
    _matchTimeUtc = matchTimeUtc;
    _matchTimeKst = matchTimeKst;
    _matchTimeKstHhmm = matchTimeKstHhmm;
    _courtName = courtName;
    _locationName = locationName;
    _durationMin = durationMin;
    _tournamentName = tournamentName;
    _tournamentLogoUrl = tournamentLogoUrl;
    _tournamentCatLogoUrl = tournamentCatLogoUrl;
    _tournamentTourLevel = tournamentTourLevel;
    _tournamentPrizeMoneyUsd = tournamentPrizeMoneyUsd;
    _tournamentCountry = tournamentCountry;
    _tournamentFlagUrl = tournamentFlagUrl;
    _tournamentDateLabel = tournamentDateLabel;
  }

  // ── getters ────────────────────────────────────────────────
  int? get id => _id;
  String? get matchCode => _matchCode;
  int? get tournamentId => _tournamentId;
  String? get tournamentCode => _tournamentCode;
  String? get tournamentStatus => _tournamentStatus;
  String? get eventName => _eventName;
  String? get matchType => _matchType;
  String? get roundName => _roundName;

  List<String>? get team1Names => _team1Names;
  String? get team1Country => _team1Country;
  String? get team1Seed => _team1Seed;
  List<int>? get team1PlayerIds => _team1PlayerIds;

  List<String>? get team2Names => _team2Names;
  String? get team2Country => _team2Country;
  String? get team2Seed => _team2Seed;
  List<int>? get team2PlayerIds => _team2PlayerIds;

  int? get winner => _winner;
  String? get score => _score;
  String? get matchStatus => _matchStatus;
  String? get matchStatusValue => _matchStatusValue;
  String? get scoreStatus => _scoreStatus;
  String? get scoreStatusValue => _scoreStatusValue;

  String? get matchTime => _matchTime;
  String? get matchTimeUtc => _matchTimeUtc;
  String? get matchTimeKst => _matchTimeKst;
  String? get matchTimeKstHhmm => _matchTimeKstHhmm;
  String? get courtName => _courtName;
  String? get locationName => _locationName;
  int? get durationMin => _durationMin;

  String? get tournamentName => _tournamentName;
  String? get tournamentLogoUrl => _tournamentLogoUrl;
  String? get tournamentCatLogoUrl => _tournamentCatLogoUrl;
  String? get tournamentTourLevel => _tournamentTourLevel;
  int? get tournamentPrizeMoneyUsd => _tournamentPrizeMoneyUsd;
  String? get tournamentCountry => _tournamentCountry;
  String? get tournamentFlagUrl => _tournamentFlagUrl;
  String? get tournamentDateLabel => _tournamentDateLabel;

  // ── setters ────────────────────────────────────────────────
  set id(int? v) => _id = v;
  set matchCode(String? v) => _matchCode = v;
  set tournamentId(int? v) => _tournamentId = v;
  set tournamentCode(String? v) => _tournamentCode = v;
  set tournamentStatus(String? v) => _tournamentStatus = v;
  set eventName(String? v) => _eventName = v;
  set matchType(String? v) => _matchType = v;
  set roundName(String? v) => _roundName = v;
  set team1Names(List<String>? v) => _team1Names = v;
  set team1Country(String? v) => _team1Country = v;
  set team1Seed(String? v) => _team1Seed = v;
  set team1PlayerIds(List<int>? v) => _team1PlayerIds = v;
  set team2Names(List<String>? v) => _team2Names = v;
  set team2Country(String? v) => _team2Country = v;
  set team2Seed(String? v) => _team2Seed = v;
  set team2PlayerIds(List<int>? v) => _team2PlayerIds = v;
  set winner(int? v) => _winner = v;
  set score(String? v) => _score = v;
  set matchStatus(String? v) => _matchStatus = v;
  set matchStatusValue(String? v) => _matchStatusValue = v;
  set scoreStatus(String? v) => _scoreStatus = v;
  set scoreStatusValue(String? v) => _scoreStatusValue = v;
  set matchTime(String? v) => _matchTime = v;
  set matchTimeUtc(String? v) => _matchTimeUtc = v;
  set matchTimeKst(String? v) => _matchTimeKst = v;
  set matchTimeKstHhmm(String? v) => _matchTimeKstHhmm = v;
  set courtName(String? v) => _courtName = v;
  set locationName(String? v) => _locationName = v;
  set durationMin(int? v) => _durationMin = v;
  set tournamentName(String? v) => _tournamentName = v;
  set tournamentLogoUrl(String? v) => _tournamentLogoUrl = v;
  set tournamentCatLogoUrl(String? v) => _tournamentCatLogoUrl = v;
  set tournamentTourLevel(String? v) => _tournamentTourLevel = v;
  set tournamentPrizeMoneyUsd(int? v) => _tournamentPrizeMoneyUsd = v;
  set tournamentCountry(String? v) => _tournamentCountry = v;
  set tournamentFlagUrl(String? v) => _tournamentFlagUrl = v;
  set tournamentDateLabel(String? v) => _tournamentDateLabel = v;

  // ── UI 편의 getters ─────────────────────────────────────────

  /// 1팀 표기 문자열 (예: "Player A / Player B"). 비어있으면 "TBD".
  String get team1Display => _joinNames(_team1Names);

  /// 2팀 표기 문자열. 비어있으면 "TBD".
  String get team2Display => _joinNames(_team2Names);

  /// 표시용 로고 URL (대회 로고 우선, 없으면 카테고리 로고).
  String? get displayLogoUrl {
    final l = _tournamentLogoUrl?.trim();
    if (l != null && l.isNotEmpty) return l;
    final c = _tournamentCatLogoUrl?.trim();
    if (c != null && c.isNotEmpty) return c;
    return null;
  }

  /// 경기 시각 DateTime (UTC 우선, 폴백은 matchTime).
  DateTime? get matchDateTime {
    final u = _matchTimeUtc;
    if (u != null) {
      final dt = DateTime.tryParse(u);
      if (dt != null) return dt;
    }
    final m = _matchTime;
    if (m == null) return null;
    return DateTime.tryParse(m);
  }

  /// KST 기준 경기 시각 DateTime (matchTimeKst 파싱).
  DateTime? get kstDateTime {
    final k = _matchTimeKst;
    if (k == null) return null;
    return DateTime.tryParse(k);
  }

  /// 승자 팀 번호 (1 또는 2). 미확정 시 null.
  int? get winnerSide {
    final w = _winner;
    if (w == 1 || w == 2) return w;
    return null;
  }

  /// 게임별 스코어 — team1/team2 기준으로 방향이 보정된 목록.
  ///
  /// 원본 스코어는 승자 우선/팀1 우선 등 표기 순서가 불확실하므로,
  /// [winnerSide]와 각 컬럼의 게임 획득 수를 비교해 team1 컬럼을 결정한다.
  /// [LiveMatchResponse.games]와 동일 로직.
  List<LiveGameScore> get games {
    if (_rawGames.isEmpty) return const <LiveGameScore>[];

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
      if (side == 1) {
        team1IsFirst = firstWins >= secondWins;
      } else {
        team1IsFirst = firstWins <= secondWins;
      }
    }

    return [
      for (final p in _rawGames)
        team1IsFirst
            ? LiveGameScore(team1: p[0], team2: p[1])
            : LiveGameScore(team1: p[1], team2: p[0]),
    ];
  }

  /// 경기가 "치러진" 상태인지 (스코어 또는 winner 또는 walkover/retired).
  bool get isPlayed {
    if (_winner == 1 || _winner == 2) return true;
    if (_rawGames.any((p) => p[0] > 0 || p[1] > 0)) return true;
    final ss = (_scoreStatusValue ?? _scoreStatus ?? '').toLowerCase().trim();
    if (ss.contains('walkover') || ss.contains('retired')) return true;
    return false;
  }

  /// Walkover 여부.
  bool get isWalkover {
    final ss = (_scoreStatusValue ?? _scoreStatus ?? '').toLowerCase().trim();
    return ss.contains('walkover');
  }

  /// Retired(기권/부상 등) 여부.
  bool get isRetired {
    final ss = (_scoreStatusValue ?? _scoreStatus ?? '').toLowerCase().trim();
    return ss.contains('retired');
  }

  /// KST 기준 표시 시간 (예: "14:30"). 파싱 실패 시 null.
  ///
  /// 서버가 사전계산해 내려준 [matchTimeKstHhmm]을 1순위로 사용한다.
  /// (디바이스 타임존과 무관하게 정확한 한국 시각.)
  /// 폴백으로 [kstDateTime]을 파싱한다(이전 응답 호환).
  String? get displayKoreanTime {
    final pre = _matchTimeKstHhmm?.trim();
    if (pre != null && pre.isNotEmpty) return pre;
    final dt = kstDateTime;
    if (dt == null) return null;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ── fromJson / toJson ──────────────────────────────────────

  TodayMatchResponse.fromJson(Map<String, dynamic> json) {
    _id = _asInt(json['id']);
    _matchCode = _str(json['match_code']);
    _tournamentId = _asInt(json['tournament_id']);
    _tournamentCode = _str(json['tournament_code']);
    _tournamentStatus = _str(json['tournament_status']);
    _eventName = _str(json['event_name']);
    _matchType = _str(json['match_type']);
    _roundName = _str(json['round_name']);

    _team1Names = _asNameList(json['team1_names']);
    _team1Country = _str(json['team1_country']);
    _team1Seed = _str(json['team1_seed']);
    _team1PlayerIds = _asIntList(json['team1_player_ids']);

    _team2Names = _asNameList(json['team2_names']);
    _team2Country = _str(json['team2_country']);
    _team2Seed = _str(json['team2_seed']);
    _team2PlayerIds = _asIntList(json['team2_player_ids']);

    _winner = _asInt(json['winner']);
    _score = _str(json['score']);
    _rawGames = _parseGames(json['score']);
    _matchStatus = _str(json['match_status']);
    _matchStatusValue = _str(json['match_status_value']);
    _scoreStatus = _str(json['score_status']);
    _scoreStatusValue = _str(json['score_status_value']);

    _matchTime = _str(json['match_time']);
    _matchTimeUtc = _str(json['match_time_utc']);
    _matchTimeKst = _str(json['match_time_kst']);
    _matchTimeKstHhmm = _str(json['match_time_kst_hhmm']);
    _courtName = _str(json['court_name']);
    _locationName = _str(json['location_name']);
    _durationMin = _asInt(json['duration_min']);

    _tournamentName = _str(json['tournament_name']);
    _tournamentLogoUrl = _str(json['tournament_logo_url']);
    _tournamentCatLogoUrl = _str(json['tournament_cat_logo_url']);
    _tournamentTourLevel = _str(json['tournament_tour_level']);
    _tournamentPrizeMoneyUsd = _asInt(json['tournament_prize_money_usd']);
    _tournamentCountry = _str(json['tournament_country']);
    _tournamentFlagUrl = _str(json['tournament_flag_url']);
    _tournamentDateLabel = _str(json['tournament_date_label']);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': _id,
      'match_code': _matchCode,
      'tournament_id': _tournamentId,
      'tournament_code': _tournamentCode,
      'tournament_status': _tournamentStatus,
      'event_name': _eventName,
      'match_type': _matchType,
      'round_name': _roundName,
      'team1_names': _team1Names,
      'team1_country': _team1Country,
      'team1_seed': _team1Seed,
      'team1_player_ids': _team1PlayerIds,
      'team2_names': _team2Names,
      'team2_country': _team2Country,
      'team2_seed': _team2Seed,
      'team2_player_ids': _team2PlayerIds,
      'winner': _winner,
      'score': _score,
      'match_status': _matchStatus,
      'match_status_value': _matchStatusValue,
      'score_status': _scoreStatus,
      'score_status_value': _scoreStatusValue,
      'match_time': _matchTime,
      'match_time_utc': _matchTimeUtc,
      'match_time_kst': _matchTimeKst,
      'match_time_kst_hhmm': _matchTimeKstHhmm,
      'court_name': _courtName,
      'location_name': _locationName,
      'duration_min': _durationMin,
      'tournament_name': _tournamentName,
      'tournament_logo_url': _tournamentLogoUrl,
      'tournament_cat_logo_url': _tournamentCatLogoUrl,
      'tournament_tour_level': _tournamentTourLevel,
      'tournament_prize_money_usd': _tournamentPrizeMoneyUsd,
      'tournament_country': _tournamentCountry,
      'tournament_flag_url': _tournamentFlagUrl,
      'tournament_date_label': _tournamentDateLabel,
    };
  }

  // ── helpers ────────────────────────────────────────────────

  static String _joinNames(List<String>? names) {
    if (names == null || names.isEmpty) return 'TBD';
    final cleaned = names.map((n) => n.trim()).where((n) => n.isNotEmpty);
    if (cleaned.isEmpty) return 'TBD';
    return cleaned.join(' / ');
  }

  /// 선수명 값을 `List<String>`으로 정규화.
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
      final parts = trimmed
          .split(RegExp(r'\s*[/,]\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return parts.isEmpty ? [trimmed] : parts;
    }
    return [value.toString()];
  }

  /// 정수 ID 배열을 `List<int>`로 정규화 (문자열 ID 허용).
  static List<int>? _asIntList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final ids = <int>[];
      for (final e in value) {
        final n = _asInt(e);
        if (n != null) ids.add(n);
      }
      return ids.isEmpty ? null : ids;
    }
    final single = _asInt(value);
    if (single != null) return <int>[single];
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final t = value.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }
    return null;
  }

  /// 스칼라/배열/숫자 값을 표시용 문자열로 정규화한다.
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
    if (value is bool) return value.toString();
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// 원본 스코어 값을 게임별 점수쌍 `[first, second]` 목록으로 파싱한다.
  ///
  /// 허용 형태 ([LiveMatchResponse._parseGames]와 동일):
  /// - 문자열 "21-18, 21-15" / "21:18 19-21 21-15"
  /// - 문자열 배열 ["21-18", "21-15"]
  /// - 숫자쌍 배열 [[21,18],[21,15]]
  /// - 맵 배열 [{team1:21,team2:18,set:1}, {home:21,away:15,set:2}, ...]
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
