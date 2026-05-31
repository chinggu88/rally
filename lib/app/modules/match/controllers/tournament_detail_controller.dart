import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/tournament_detail_response.dart';
import '../../../data/models/tournament_match_response.dart';
import '../../../data/models/tournament_response.dart';
import '../../../data/repositories/tournament_repository.dart';

/// 대회 상세 화면 컨트롤러.
///
/// 리스트 화면([MatchView])에서 [Get.toNamed] 의 `arguments` 로 전달된
/// 대회 컨텍스트(`tournament_id` + 리스트 항목 [TournamentResponse])를 보존하고,
/// Supabase Edge Function `get-tournament` 로 상세를 조회해 병합한다.
///
/// 상세 데이터가 아직 없거나(404) 식별자가 없어도, 리스트에서 받은 폴백
/// 컨텍스트로 히어로/정보 영역을 그릴 수 있도록 설계한다.
///
/// `status`/`has_live_scores`/기간으로 [phase]를 계산해
/// 경기 전(before)·경기 중(live)·경기 완료(completed) 3가지 상태를 구분한다.
class TournamentDetailController extends GetxController {
  /// arguments 키 — 상세 조회용 `bwf_tournaments.tournament_id`
  static const String argTournamentId = 'tournament_id';

  /// arguments 키 — 리스트 항목 폴백 컨텍스트 ([TournamentResponse])
  static const String argFallback = 'fallback';

  final TournamentRepository _tournamentRepository =
      Get.find<TournamentRepository>();

  /// 상세 조회 대상 tournament_id (null이면 조회 불가 → notFound 처리)
  int? _tournamentId;
  int? get tournamentId => _tournamentId;

  /// 리스트에서 받은 폴백 컨텍스트 (상세 로드 전/실패 시 표시용)
  TournamentResponse? _fallback;
  TournamentResponse? get fallback => _fallback;

  /// API 요청 중 로딩 상태 여부
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => _isLoading.value = val;

  /// 조회된 상세 (null이면 미로드 또는 미존재)
  final _detail = Rxn<TournamentDetailResponse>();
  TournamentDetailResponse? get detail => _detail.value;
  set detail(TournamentDetailResponse? val) => _detail.value = val;

  /// 상세 데이터가 존재하지 않음(404 등) 여부
  final _notFound = false.obs;
  bool get notFound => _notFound.value;
  set notFound(bool val) => _notFound.value = val;

  /// 에러 메시지 (null이면 정상 상태로 간주)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => _errorMessage.value = val;

  /// 경기(매치) 목록 (match_time 오름차순)
  final _matches = <TournamentMatchResponse>[].obs;
  List<TournamentMatchResponse> get matches => _matches;

  /// 경기 목록 로딩 상태
  final _isMatchesLoading = false.obs;
  bool get isMatchesLoading => _isMatchesLoading.value;
  set isMatchesLoading(bool val) => _isMatchesLoading.value = val;

  /// 경기 목록 에러 메시지 (null이면 정상)
  final _matchesError = RxnString();
  String? get matchesError => _matchesError.value;
  set matchesError(String? val) => _matchesError.value = val;

  /// 현재 선택된 탭 인덱스 (0 = 요약, 1.. = 날짜, 마지막 = PODIUM)
  final _selectedTabIndex = 0.obs;
  int get selectedTabIndex => _selectedTabIndex.value;

  /// 탭 전환
  void changeTab(int index) {
    if (index < 0) return;
    _selectedTabIndex.value = index;
  }

  /// 외부 링크 중복 오픈 방지 플래그
  bool _isOpeningExternal = false;

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    fetchDetail();
    fetchMatches();
  }

  /// 네비게이션 arguments 파싱 — Map / TournamentResponse / int 모두 허용.
  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      _tournamentId = _asInt(args[argTournamentId]);
      final fb = args[argFallback];
      if (fb is TournamentResponse) {
        _fallback = fb;
        _tournamentId ??= fb.tournamentId;
      }
    } else if (args is TournamentResponse) {
      _fallback = args;
      _tournamentId = args.tournamentId;
    } else if (args is int) {
      _tournamentId = args;
    }
  }

  /// 대회 상세를 조회한다.
  Future<void> fetchDetail() async {
    final id = _tournamentId;
    if (id == null || id <= 0) {
      // 식별자가 없으면 조회 불가 — 폴백 컨텍스트만으로 표시
      notFound = true;
      isLoading = false;
      return;
    }

    try {
      isLoading = true;
      errorMessage = null;
      notFound = false;

      final response =
          await _tournamentRepository.getTournament(tournamentId: id);
      final tournament = response.tournament;

      if (tournament == null) {
        detail = null;
        notFound = true;
      } else {
        detail = tournament;
        notFound = false;
      }
    } catch (e) {
      log('TournamentDetailController.fetchDetail error: $e');
      errorMessage = '대회 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      isLoading = false;
    }
  }

  /// 대회 경기(매치) 목록을 조회한다.
  Future<void> fetchMatches() async {
    final id = _tournamentId;
    if (id == null || id <= 0) {
      _matches.clear();
      isMatchesLoading = false;
      return;
    }

    try {
      isMatchesLoading = true;
      matchesError = null;

      final response =
          await _tournamentRepository.getTournamentMatches(tournamentId: id);
      _matches.assignAll(
        response.matches ?? const <TournamentMatchResponse>[],
      );
    } catch (e) {
      log('TournamentDetailController.fetchMatches error: $e');
      matchesError = '경기 결과를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      _matches.clear();
    } finally {
      isMatchesLoading = false;
    }
  }

  /// 경기 결과 존재 여부
  bool get hasMatches => _matches.isNotEmpty;

  /// 라운드 탭 고정 우선순위 (R32 → R16 → QF → SF → Final).
  ///
  /// 인덱스가 작을수록 먼저 노출된다. 목록에 없는 라운드(예: R128/R64/예선/기타)는
  /// `_roundRank`가 큰 값을 돌려주므로 뒤로 밀린다.
  static const List<String> _roundOrder = <String>[
    'R128',
    'R64',
    'R32',
    'R16',
    'QF',
    'SF',
    'Final',
  ];

  /// 원본 라운드명을 표준 키로 정규화한다 (`_shortRound`와 정합).
  static String _normalizeRoundKey(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return '기타';
    final lower = r.toLowerCase();

    final roundOf = RegExp(r'(?:round of|1/)\s*(\d+)').firstMatch(lower);
    if (roundOf != null) return 'R${roundOf.group(1)}';

    if (lower.contains('final') &&
        !lower.contains('semi') &&
        !lower.contains('quarter')) {
      return 'Final';
    }
    if (lower.contains('semi')) return 'SF';
    if (lower.contains('quarter')) return 'QF';
    if (lower.contains('qualif')) return '예선';
    return r;
  }

  static int _roundRank(String key) {
    final idx = _roundOrder.indexOf(key);
    return idx < 0 ? _roundOrder.length : idx;
  }

  /// 주어진 경기 목록을 라운드명 기준으로 그룹핑한다.
  ///
  /// R32 → R16 → QF → SF → Final 고정 우선순위로 정렬한다. 우선순위에 없는
  /// 라운드는 뒤쪽에 첫 등장 순서대로 붙는다.
  List<TournamentMatchRound> _groupByRound(
    List<TournamentMatchResponse> source,
  ) {
    final map = <String, List<TournamentMatchResponse>>{};
    final order = <String>[];
    for (final m in source) {
      final key = _normalizeRoundKey(m.roundName ?? '');
      if (!map.containsKey(key)) {
        map[key] = <TournamentMatchResponse>[];
        order.add(key);
      }
      map[key]!.add(m);
    }
    order.sort((a, b) {
      final ra = _roundRank(a);
      final rb = _roundRank(b);
      if (ra != rb) return ra.compareTo(rb);
      // 동일 rank(주로 둘 다 '기타' 등)는 첫 등장 순서 유지.
      return 0;
    });
    return [
      for (final k in order) TournamentMatchRound(name: k, matches: map[k]!),
    ];
  }

  /// 전체 경기를 라운드명 기준으로 그룹핑한다.
  List<TournamentMatchRound> get matchRounds => _groupByRound(_matches);

  /// 경기를 일자(로컬 날짜)별로 그룹핑한다.
  ///
  /// `match_time` 오름차순 정렬을 전제로 날짜를 오름차순 묶고, 각 날짜 안은
  /// 다시 라운드별로 그룹핑한다. `match_time`이 없는 경기는 맨 뒤 `미정` 그룹.
  List<TournamentDayGroup> get matchDays {
    final map = <String, List<TournamentMatchResponse>>{};
    final order = <String>[];
    const noDateKey = '__no_date__';

    for (final m in _matches) {
      final dt = m.matchDateTime?.toLocal();
      final key = dt == null
          ? noDateKey
          : '${dt.year.toString().padLeft(4, '0')}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')}';
      if (!map.containsKey(key)) {
        map[key] = <TournamentMatchResponse>[];
        order.add(key);
      }
      map[key]!.add(m);
    }

    // 날짜 키는 오름차순, 미정은 항상 맨 뒤
    order.sort((a, b) {
      if (a == noDateKey) return 1;
      if (b == noDateKey) return -1;
      return a.compareTo(b);
    });

    return [
      for (final key in order)
        TournamentDayGroup(
          date: key == noDateKey ? null : DateTime.tryParse(key),
          dayLabel: key == noDateKey
              ? '–'
              : key.substring(8, 10),
          monthLabel: key == noDateKey
              ? '미정'
              : _monthAbbr(int.tryParse(key.substring(5, 7))),
          rounds: _groupByRound(map[key]!),
        ),
    ];
  }

  /// 종목별 우승자(PODIUM) — 결승(Final) 경기에서 도출.
  ///
  /// `round_name`에 `final`이 포함되고 `semi`/`quarter`가 없는 경기를 결승으로
  /// 보고, `winnerSide`로 챔피언/준우승을 구분한다. 종목(`event_name`)별 1건.
  List<PodiumEntry> get podium {
    final result = <PodiumEntry>[];
    final seenEvents = <String>{};

    for (final m in _matches) {
      final round = (m.roundName ?? '').toLowerCase();
      final isFinal = round.contains('final') &&
          !round.contains('semi') &&
          !round.contains('quarter') &&
          !round.contains('1/');
      if (!isFinal) continue;

      final side = m.winnerSide;
      if (side == null) continue;

      final event = (m.eventName ?? '').trim();
      final eventKey = event.isEmpty ? '기타' : event;
      if (seenEvents.contains(eventKey)) continue;
      seenEvents.add(eventKey);

      final championIsTeam1 = side == 1;
      final g = m.games;
      result.add(
        PodiumEntry(
          eventName: eventKey,
          champion: championIsTeam1 ? m.team1Display : m.team2Display,
          championCountry:
              championIsTeam1 ? m.team1Country : m.team2Country,
          runnerUp: championIsTeam1 ? m.team2Display : m.team1Display,
          runnerUpCountry:
              championIsTeam1 ? m.team2Country : m.team1Country,
          score: m.scoreDisplay,
          championPoints: [
            for (final s in g) championIsTeam1 ? s.team1 : s.team2,
          ],
          runnerUpPoints: [
            for (final s in g) championIsTeam1 ? s.team2 : s.team1,
          ],
        ),
      );
    }
    return result;
  }

  /// PODIUM 탭 노출 여부
  bool get hasPodium => podium.isNotEmpty;

  /// 월(1~12)을 영어 약어로 변환. 범위 밖이면 빈 문자열.
  static String _monthAbbr(int? month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month == null || month < 1 || month > 12) return '';
    return names[month - 1];
  }

  /// 재시도 버튼용 — 상세를 다시 불러온다.
  Future<void> refreshDetail() async {
    await fetchDetail();
  }

  /// 재시도 버튼용 — 상세와 경기 결과를 함께 다시 불러온다.
  Future<void> refreshAll() async {
    await Future.wait(<Future<void>>[fetchDetail(), fetchMatches()]);
  }

  // ── 병합 getter (상세 우선, 없으면 폴백) ───────────────────────────────

  String? get name => _firstNonEmpty(detail?.name, _fallback?.name);
  String? get tourLevel =>
      _firstNonEmpty(detail?.tourLevel, _fallback?.tourLevel);
  String? get startDate =>
      _firstNonEmpty(detail?.startDate, _fallback?.startDate);
  String? get endDate => _firstNonEmpty(detail?.endDate, _fallback?.endDate);
  String? get dateLabel =>
      _firstNonEmpty(detail?.dateLabel, _fallback?.dateLabel);
  String? get country => _firstNonEmpty(detail?.country, _fallback?.country);
  String? get location =>
      _firstNonEmpty(detail?.location, _fallback?.location);
  String? get detailUrl =>
      _firstNonEmpty(detail?.detailUrl, _fallback?.detailUrl);
  String? get flagUrl => _firstNonEmpty(detail?.flagUrl, _fallback?.flagUrl);
  String? get logoUrl => _firstNonEmpty(detail?.logoUrl, _fallback?.logoUrl);
  String? get catLogoUrl =>
      _firstNonEmpty(detail?.catLogoUrl, _fallback?.catLogoUrl);
  String? get status => _firstNonEmpty(detail?.status, _fallback?.status);
  double? get prizeMoneyUsd =>
      detail?.prizeMoneyUsd ?? _fallback?.prizeMoneyUsd;
  bool get hasLiveScores =>
      detail?.hasLiveScores ?? _fallback?.hasLiveScores ?? false;

  DateTime? get _startDateTime {
    final s = startDate;
    return s == null ? null : DateTime.tryParse(s);
  }

  DateTime? get _endDateTime {
    final e = endDate;
    return e == null ? null : DateTime.tryParse(e);
  }

  // ── 진행 단계(phase) 계산 ──────────────────────────────────────────────

  /// 대회 진행 단계 — 경기 전/중/완료.
  ///
  /// 우선순위:
  /// 1) 시작/종료일과 오늘 날짜 비교 (가장 신뢰도 높은 근거)
  /// 2) 날짜가 전혀 없을 때만 `status` 텍스트 힌트로 추정
  /// 3) 그래도 알 수 없으면 `has_live_scores`로 진행 중 추정
  ///
  /// `has_live_scores`는 "라이브 스코어 제공 가능" 여부(종료 후에도 true일 수
  /// 있음)이므로 날짜보다 우선하지 않는다. 이를 우선하면 종료/예정 대회가
  /// 항상 live로 잘못 판정된다.
  TournamentPhase get phase {
    final today = _today();
    final start = _dateOnly(_startDateTime);
    final end = _dateOnly(_endDateTime);

    // 1) 날짜 기준 — 기간이 있으면 이것이 우선
    if (end != null && today.isAfter(end)) return TournamentPhase.completed;
    if (start != null && today.isBefore(start)) return TournamentPhase.before;
    if (start != null || end != null) return TournamentPhase.live;

    // 2) 날짜가 전혀 없을 때만 status 힌트
    final s = (status ?? '').toLowerCase();
    if (s.isNotEmpty) {
      if (s.contains('complete') ||
          s.contains('finish') ||
          s.contains('result') ||
          s.contains('end') ||
          s.contains('past')) {
        return TournamentPhase.completed;
      }
      if (s.contains('live') ||
          s.contains('ongoing') ||
          s.contains('progress') ||
          s.contains('running')) {
        return TournamentPhase.live;
      }
      if (s.contains('upcoming') ||
          s.contains('soon') ||
          s.contains('schedule')) {
        return TournamentPhase.before;
      }
    }

    // 3) 마지막 폴백 — 라이브 스코어 제공 중이면 진행 중으로 간주
    if (hasLiveScores) return TournamentPhase.live;

    return TournamentPhase.before;
  }

  /// 개막까지 남은 일수 (경기 전일 때만 의미 있음). 계산 불가/과거면 null.
  int? get daysUntilStart {
    final start = _dateOnly(_startDateTime);
    if (start == null) return null;
    final diff = start.difference(_today()).inDays;
    return diff >= 0 ? diff : null;
  }

  /// 대회 상세 페이지(BWF 공식)를 외부 브라우저로 연다.
  ///
  /// 경기 중이면 "실시간 스코어", 완료면 "결과", 그 외엔 "공식 페이지"로
  /// 동작은 동일하며 `detail_url`이 비어있으면 무동작한다.
  Future<void> openExternalDetail() async {
    if (_isOpeningExternal) return;

    final urlString = detailUrl;
    if (urlString == null || urlString.isEmpty) {
      log('TournamentDetailController.openExternalDetail: detailUrl empty, '
          'tournamentId=$_tournamentId');
      return;
    }

    final uri = Uri.tryParse(urlString);
    if (uri == null) {
      log('TournamentDetailController.openExternalDetail: invalid url='
          '$urlString');
      return;
    }

    try {
      _isOpeningExternal = true;
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        log('TournamentDetailController.openExternalDetail: cannot launch '
            '$uri');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      log('TournamentDetailController.openExternalDetail error: $e');
    } finally {
      if (kReleaseMode) {
        _isOpeningExternal = false;
      } else {
        _isOpeningExternal = false;
      }
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────

  static String? _firstNonEmpty(String? a, String? b) {
    if (a != null && a.trim().isNotEmpty) return a;
    if (b != null && b.trim().isNotEmpty) return b;
    return null;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime? _dateOnly(DateTime? dt) =>
      dt == null ? null : DateTime(dt.year, dt.month, dt.day);

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 라운드 단위 경기 그룹 (라운드명 + 해당 경기들)
class TournamentMatchRound {
  TournamentMatchRound({required this.name, required this.matches});

  /// 라운드명 (예: "Final", "Semi-final")
  final String name;

  /// 해당 라운드의 경기 목록
  final List<TournamentMatchResponse> matches;
}

/// 일자 단위 경기 그룹 (날짜 라벨 + 라운드별 그룹)
class TournamentDayGroup {
  TournamentDayGroup({
    required this.date,
    required this.dayLabel,
    required this.monthLabel,
    required this.rounds,
  });

  /// 해당 일자 (null이면 일정 미정)
  final DateTime? date;

  /// 일(day) 라벨 — 예: "06"
  final String dayLabel;

  /// 월 약어 라벨 — 예: "Jan" (미정이면 "미정")
  final String monthLabel;

  /// 해당 날짜의 라운드별 경기 그룹
  final List<TournamentMatchRound> rounds;
}

/// PODIUM 항목 — 종목별 우승/준우승
class PodiumEntry {
  PodiumEntry({
    required this.eventName,
    required this.champion,
    required this.championCountry,
    required this.runnerUp,
    required this.runnerUpCountry,
    required this.score,
    required this.championPoints,
    required this.runnerUpPoints,
  });

  /// 종목명 (예: "Men's Singles")
  final String eventName;

  /// 우승 팀/선수 표기
  final String champion;

  /// 우승 국가
  final String? championCountry;

  /// 준우승 팀/선수 표기
  final String? runnerUp;

  /// 준우승 국가
  final String? runnerUpCountry;

  /// 결승 스코어(폴백 문자열)
  final String? score;

  /// 우승 측 게임별 득점
  final List<int> championPoints;

  /// 준우승 측 게임별 득점
  final List<int> runnerUpPoints;
}
