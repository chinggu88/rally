/// 라이브 경기(매치) 단일 항목 응답 모델
///
/// Edge Function `get-live-matches`의 `matches[]` 원소(`bwf_live_matches` 1행)에
/// 1:1 매핑된다. 해당 row는 대회/매치/팀 비정규화된 풍부한 필드를 포함하기 때문에
/// 클라이언트는 JOIN 없이 라이브 카드를 그릴 수 있다.
///
/// 서버 값의 실제 타입(문자열/배열/정수)이 유동적일 수 있어 모든 파싱을
/// 방어적으로 처리한다([TournamentMatchResponse]와 동일 패턴).
class LiveMatchResponse {
  // ── 매치 기본 ───────────────────────────────────────────────
  /// bwf_live_matches PK
  int? _id;

  /// 대회 ID (BWF tournament id)
  int? _tournamentId;

  /// 대회 코드
  String? _tournamentCode;

  /// 대회 상태 (이 응답에서는 항상 'live')
  String? _tournamentStatus;

  /// 종목명 (예: "MS", "Men's Singles" 등 — 표기 유동적)
  String? _eventName;

  /// 경기 유형
  String? _matchType;

  /// 라운드명 (예: "Final", "Semi-final", "Round of 16")
  String? _roundName;

  // ── team1 ──────────────────────────────────────────────────
  /// 1팀 선수명 목록 (단식 1명 / 복식 2명)
  List<String>? _team1Names;

  /// 1팀 국가
  String? _team1Country;

  /// 1팀 시드
  String? _team1Seed;

  /// 1팀 선수 ID 목록
  List<int>? _team1PlayerIds;

  /// 1팀 선수 아바타 URL 목록 (TODO: edge function 추후 제공 예정)
  /// 단식이면 1개, 복식이면 2개. null/빈 배열이면 placeholder 표시.
  List<String>? _team1PlayerAvatars;

  // ── team2 ──────────────────────────────────────────────────
  List<String>? _team2Names;
  String? _team2Country;
  String? _team2Seed;
  List<int>? _team2PlayerIds;

  /// 2팀 선수 아바타 URL 목록 (TODO: edge function 추후 제공 예정)
  List<String>? _team2PlayerAvatars;

  // ── 결과 / 진행 ────────────────────────────────────────────
  /// 승자 (원본 값 — "1"/"2" 또는 팀/선수명일 수 있음)
  String? _winner;

  /// 스코어 원본 (예: "21-18, 21-15" 혹은 "12-9, 21-15, 18-15(p)" 등)
  String? _score;

  /// 원본 스코어에서 파싱한 게임별 점수쌍(소스 순서 `[first, second]`).
  /// 방향(어느 쪽이 team1)은 [games] getter에서 승자 기준으로 보정한다.
  List<List<int>> _rawGames = const <List<int>>[];

  /// 경기 상태 (live, in-progress, completed 등 — 표기 유동적)
  String? _matchStatus;

  /// 경기 상태 표시값 (서버가 별도 라벨링 한 값)
  String? _matchStatusValue;

  /// 스코어 상태 (게임 종료/진행 중 등)
  String? _scoreStatus;

  /// 스코어 상태 표시값
  String? _scoreStatusValue;

  /// 경기 시각 (현지 또는 대회 시간 ISO)
  String? _matchTime;

  /// 경기 시각 UTC ISO
  String? _matchTimeUtc;

  /// 코트명
  String? _courtName;

  /// 경기 소요 시간(분)
  int? _durationMin;

  /// 라이브 승격 시각 (ISO)
  String? _promotedAt;

  /// 마지막 폴링 시각 (ISO)
  String? _lastPolledAt;

  // ── 대회 비정규화 ───────────────────────────────────────────
  String? _slug;
  String? _name;
  String? _startDate;
  String? _endDate;
  String? _dateLabel;
  int? _prizeMoneyUsd;
  String? _detailUrl;
  String? _logoUrl;
  String? _headerImageUrl;
  String? _headerImageMobileUrl;
  String? _catLogoUrl;
  String? _categoryName;
  int? _tournamentCategoryId;
  int? _tournamentSeriesId;
  bool? _isEtihad;

  LiveMatchResponse({
    int? id,
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
    List<String>? team1PlayerAvatars,
    List<String>? team2Names,
    String? team2Country,
    String? team2Seed,
    List<int>? team2PlayerIds,
    List<String>? team2PlayerAvatars,
    String? winner,
    String? score,
    String? matchStatus,
    String? matchStatusValue,
    String? scoreStatus,
    String? scoreStatusValue,
    String? matchTime,
    String? matchTimeUtc,
    String? courtName,
    int? durationMin,
    String? promotedAt,
    String? lastPolledAt,
    String? slug,
    String? name,
    String? startDate,
    String? endDate,
    String? dateLabel,
    int? prizeMoneyUsd,
    String? detailUrl,
    String? logoUrl,
    String? headerImageUrl,
    String? headerImageMobileUrl,
    String? catLogoUrl,
    String? categoryName,
    int? tournamentCategoryId,
    int? tournamentSeriesId,
    bool? isEtihad,
  }) {
    _id = id;
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
    _team1PlayerAvatars = team1PlayerAvatars;
    _team2Names = team2Names;
    _team2Country = team2Country;
    _team2Seed = team2Seed;
    _team2PlayerIds = team2PlayerIds;
    _team2PlayerAvatars = team2PlayerAvatars;
    _winner = winner;
    _score = score;
    _matchStatus = matchStatus;
    _matchStatusValue = matchStatusValue;
    _scoreStatus = scoreStatus;
    _scoreStatusValue = scoreStatusValue;
    _matchTime = matchTime;
    _matchTimeUtc = matchTimeUtc;
    _courtName = courtName;
    _durationMin = durationMin;
    _promotedAt = promotedAt;
    _lastPolledAt = lastPolledAt;
    _slug = slug;
    _name = name;
    _startDate = startDate;
    _endDate = endDate;
    _dateLabel = dateLabel;
    _prizeMoneyUsd = prizeMoneyUsd;
    _detailUrl = detailUrl;
    _logoUrl = logoUrl;
    _headerImageUrl = headerImageUrl;
    _headerImageMobileUrl = headerImageMobileUrl;
    _catLogoUrl = catLogoUrl;
    _categoryName = categoryName;
    _tournamentCategoryId = tournamentCategoryId;
    _tournamentSeriesId = tournamentSeriesId;
    _isEtihad = isEtihad;
  }

  // ── getters ────────────────────────────────────────────────
  int? get id => _id;
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

  List<String>? get team1PlayerAvatars => _team1PlayerAvatars;

  List<String>? get team2Names => _team2Names;
  String? get team2Country => _team2Country;
  String? get team2Seed => _team2Seed;
  List<int>? get team2PlayerIds => _team2PlayerIds;
  List<String>? get team2PlayerAvatars => _team2PlayerAvatars;

  String? get winner => _winner;
  String? get score => _score;
  String? get matchStatus => _matchStatus;
  String? get matchStatusValue => _matchStatusValue;
  String? get scoreStatus => _scoreStatus;
  String? get scoreStatusValue => _scoreStatusValue;
  String? get matchTime => _matchTime;
  String? get matchTimeUtc => _matchTimeUtc;
  String? get courtName => _courtName;
  int? get durationMin => _durationMin;
  String? get promotedAt => _promotedAt;
  String? get lastPolledAt => _lastPolledAt;

  String? get slug => _slug;
  String? get name => _name;
  String? get startDate => _startDate;
  String? get endDate => _endDate;
  String? get dateLabel => _dateLabel;
  int? get prizeMoneyUsd => _prizeMoneyUsd;
  String? get detailUrl => _detailUrl;
  String? get logoUrl => _logoUrl;
  String? get headerImageUrl => _headerImageUrl;
  String? get headerImageMobileUrl => _headerImageMobileUrl;
  String? get catLogoUrl => _catLogoUrl;
  String? get categoryName => _categoryName;
  int? get tournamentCategoryId => _tournamentCategoryId;
  int? get tournamentSeriesId => _tournamentSeriesId;
  bool? get isEtihad => _isEtihad;

  // ── UI 편의 getters ─────────────────────────────────────────

  /// 1팀 표기 문자열 (예: "Player A / Player B"). 비어있으면 "TBD".
  String get team1Display => _joinNames(_team1Names);

  /// 2팀 표기 문자열. 비어있으면 "TBD".
  String get team2Display => _joinNames(_team2Names);

  /// 표시용 로고 URL (대회 로고 우선, 없으면 카테고리 로고)
  String? get displayLogoUrl {
    final l = _logoUrl?.trim();
    if (l != null && l.isNotEmpty) return l;
    final c = _catLogoUrl?.trim();
    if (c != null && c.isNotEmpty) return c;
    return null;
  }

  /// 표시용 헤더 이미지 URL (모바일 우선, 없으면 데스크톱)
  String? get displayHeaderImageUrl {
    final m = _headerImageMobileUrl?.trim();
    if (m != null && m.isNotEmpty) return m;
    final d = _headerImageUrl?.trim();
    if (d != null && d.isNotEmpty) return d;
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

  /// 라이브 여부 — tournament_status 또는 match_status에 'live' 포함 시 true.
  bool get isLive {
    final t = (_tournamentStatus ?? '').toLowerCase();
    if (t.contains('live')) return true;
    final m = (_matchStatus ?? '').toLowerCase();
    if (m.contains('live') || m.contains('progress') || m.contains('in-play')) {
      return true;
    }
    return false;
  }

  /// 경기 종료(완료) 여부 — status 또는 승자/스코어 존재로 판단.
  bool get isCompleted {
    final s = (_matchStatus ?? '').toLowerCase();
    if (s.contains('complete') ||
        s.contains('finish') ||
        s.contains('result') ||
        s.contains('done')) {
      return true;
    }
    return winnerSide != null && _score != null && _score!.trim().isNotEmpty;
  }

  /// 승자 팀 번호 (1 또는 2). 판별 불가 시 null.
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

  /// 게임별 스코어 존재 여부
  bool get hasGameScores => _rawGames.isNotEmpty;

  /// 스코어 표시 폴백 문자열 (게임 파싱 실패 시 사용)
  String? get scoreDisplay => _score;

  /// 진행 중인 게임 인덱스 추정.
  ///
  /// 완료 게임은 한쪽이 21점 이상 도달 + 2점차 우위로 간주한다.
  /// 마지막 게임이 그 조건을 만족하지 못하면 그 게임이 진행 중인 것으로 본다.
  int? get currentGameIndex {
    if (_rawGames.isEmpty) return null;
    if (isCompleted) return null;
    for (var i = 0; i < _rawGames.length; i++) {
      final pair = _rawGames[i];
      final a = pair[0];
      final b = pair[1];
      final completed = (a >= 21 || b >= 21) && (a - b).abs() >= 2;
      if (!completed) return i;
    }
    return _rawGames.length - 1;
  }

  // ── 부분 갱신 (Realtime용) ─────────────────────────────────

  /// Realtime UPDATE/INSERT payload에서 `score` 필드만 갱신한다.
  ///
  /// 다른 필드(팀 정보, 대회 정보, 아바타 등)는 초기 fetch 값을 유지하고,
  /// 변동이 잦은 스코어 관련 값(`_score`와 파생 `_rawGames`)만 덮어쓴다.
  ///
  /// payload에 `score` 키가 아예 없으면 no-op.
  void applyScoreFromJson(Map<String, dynamic> json) {
    if (!json.containsKey('score')) return;
    final raw = json['score'];
    _score = _str(raw);
    _rawGames = _parseGames(raw);
  }

  // ── fromJson / toJson ──────────────────────────────────────

  LiveMatchResponse.fromJson(Map<String, dynamic> json) {
    _id = _asInt(json['id']);
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
    _team1PlayerAvatars = _asUrlList(json['team1_player_avatars']);
    _team2Names = _asNameList(json['team2_names']);
    _team2Country = _str(json['team2_country']);
    _team2Seed = _str(json['team2_seed']);
    _team2PlayerIds = _asIntList(json['team2_player_ids']);
    _team2PlayerAvatars = _asUrlList(json['team2_player_avatars']);
    _winner = _str(json['winner']);
    _score = _str(json['score']);
    _rawGames = _parseGames(json['score']);
    _matchStatus = _str(json['match_status']);
    _matchStatusValue = _str(json['match_status_value']);
    _scoreStatus = _str(json['score_status']);
    _scoreStatusValue = _str(json['score_status_value']);
    _matchTime = _str(json['match_time']);
    _matchTimeUtc = _str(json['match_time_utc']);
    _courtName = _str(json['court_name']);
    _durationMin = _asInt(json['duration_min']);
    _promotedAt = _str(json['promoted_at']);
    _lastPolledAt = _str(json['last_polled_at']);
    _slug = _str(json['slug']);
    _name = _str(json['name']);
    _startDate = _str(json['start_date']);
    _endDate = _str(json['end_date']);
    _dateLabel = _str(json['date_label']);
    _prizeMoneyUsd = _asInt(json['prize_money_usd']);
    _detailUrl = _str(json['detail_url']);
    _logoUrl = _str(json['logo_url']);
    _headerImageUrl = _str(json['header_image_url']);
    _headerImageMobileUrl = _str(json['header_image_mobile_url']);
    _catLogoUrl = _str(json['cat_logo_url']);
    _categoryName = _str(json['category_name']);
    _tournamentCategoryId = _asInt(json['tournament_category_id']);
    _tournamentSeriesId = _asInt(json['tournament_series_id']);
    _isEtihad = _asBool(json['is_etihad']);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': _id,
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
      'team1_player_avatars': _team1PlayerAvatars,
      'team2_names': _team2Names,
      'team2_country': _team2Country,
      'team2_seed': _team2Seed,
      'team2_player_ids': _team2PlayerIds,
      'team2_player_avatars': _team2PlayerAvatars,
      'winner': _winner,
      'score': _score,
      'match_status': _matchStatus,
      'match_status_value': _matchStatusValue,
      'score_status': _scoreStatus,
      'score_status_value': _scoreStatusValue,
      'match_time': _matchTime,
      'match_time_utc': _matchTimeUtc,
      'court_name': _courtName,
      'duration_min': _durationMin,
      'promoted_at': _promotedAt,
      'last_polled_at': _lastPolledAt,
      'slug': _slug,
      'name': _name,
      'start_date': _startDate,
      'end_date': _endDate,
      'date_label': _dateLabel,
      'prize_money_usd': _prizeMoneyUsd,
      'detail_url': _detailUrl,
      'logo_url': _logoUrl,
      'header_image_url': _headerImageUrl,
      'header_image_mobile_url': _headerImageMobileUrl,
      'cat_logo_url': _catLogoUrl,
      'category_name': _categoryName,
      'tournament_category_id': _tournamentCategoryId,
      'tournament_series_id': _tournamentSeriesId,
      'is_etihad': _isEtihad,
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

  /// URL 문자열 배열을 `List<String>`으로 정규화.
  ///
  /// - 문자열 배열 그대로 받음
  /// - 단일 문자열은 1-원소 리스트로
  /// - 빈 문자열/null 원소는 빈 문자열로 보존(선수 순서 유지를 위해)
  static List<String>? _asUrlList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final urls = value
          .map((e) => e?.toString().trim() ?? '')
          .toList(growable: false);
      if (urls.every((e) => e.isEmpty)) return null;
      return urls;
    }
    if (value is String) {
      final t = value.trim();
      if (t.isEmpty) return null;
      return <String>[t];
    }
    return null;
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

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final t = value.trim().toLowerCase();
      if (t.isEmpty) return null;
      if (t == 'true' || t == 't' || t == '1' || t == 'yes' || t == 'y') {
        return true;
      }
      if (t == 'false' || t == 'f' || t == '0' || t == 'no' || t == 'n') {
        return false;
      }
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
  /// 허용 형태(TournamentMatchResponse와 동일):
  /// - 문자열 "21-18, 21-15" / "21:18 19-21 21-15"
  /// - 문자열 배열 ["21-18", "21-15"]
  /// - 숫자쌍 배열 [[21,18],[21,15]]
  /// - 맵 배열 [{team1:21,team2:18}, ...]
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

/// 게임 단위 스코어 (team1/team2 기준으로 방향 보정된 점수)
class LiveGameScore {
  const LiveGameScore({required this.team1, required this.team2});

  /// team1 득점
  final int team1;

  /// team2 득점
  final int team2;
}
