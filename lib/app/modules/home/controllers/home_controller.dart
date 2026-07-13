import 'dart:async';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/active_tournament_response.dart';
import '../../../data/models/get_news_cards_response.dart';
import '../../../data/models/live_match_response.dart';
import '../../../data/models/news_card_response.dart';
import '../../../data/models/today_match_response.dart';
import '../../../data/repositories/live_match_repository.dart';
import '../../../data/repositories/news_card_repository.dart';
import '../../../data/repositories/today_match_repository.dart';
import '../../../data/repositories/tournament_repository.dart';

/// 홈(뉴스) 화면 컨트롤러.
///
/// 현재 홈 탭은 뉴스 placeholder + 상단 고정 라이브 매치 영역을 제공한다.
/// 라이브 매치는 Supabase Edge Function `get-live-matches`에서 초기 로드하고,
/// 이후 Supabase Realtime으로 `bwf_live_matches` 테이블의 변경을 구독해
/// 스코어가 바뀌면 즉시 UI에 반영한다.
///
/// 동시 호출(예: 빠른 pull-to-refresh)에서의 race condition을 방지하기 위해
/// `_inflightToken` 카운터를 사용한다.
class HomeController extends GetxController {
  static HomeController get to => Get.find();

  final LiveMatchRepository _liveMatchRepository =
      Get.find<LiveMatchRepository>();

  final TodayMatchRepository _todayMatchRepository =
      Get.find<TodayMatchRepository>();

  final NewsCardRepository _newsCardRepository = Get.find<NewsCardRepository>();

  final TournamentRepository _tournamentRepository =
      Get.find<TournamentRepository>();

  /// 카드뉴스 페이지당 개수 (Edge Function 기본값과 동일)
  static const int _newsPageSize = 20;

  // ── 통합 로딩 상태 (스켈레톤) ────────────────────────────────

  /// 초기 로딩에서 호출하는 API 수 (남은 대회 / 라이브 / 오늘 경기 / 카드뉴스)
  static const int _initialApiCount = 4;

  /// 초기 로딩이 완료된 API 수. [_initialApiCount]와 같아지면 로딩 종료.
  int loadingCnt = 0;

  /// 홈 초기 로딩 중 여부 (true면 스켈레톤 표시)
  final _isLoading = true.obs;
  bool get isLoading => _isLoading.value;

  /// 초기 API 하나가 완료될 때마다 호출. 전부 완료되면 로딩을 끝낸다.
  /// 초기 로딩이 끝난 뒤(pull-to-refresh 등)에는 no-op.
  void _onApiLoaded() {
    if (!_isLoading.value) return;
    loadingCnt++;
    if (loadingCnt >= _initialApiCount) {
      _isLoading.value = false;
    }
  }

  /// 라이브 매치 목록 (start_date ASC → id ASC)
  final _liveMatches = <LiveMatchResponse>[].obs;
  List<LiveMatchResponse> get liveMatches => _liveMatches;

  /// 라이브 매치 에러 메시지 (null이면 정상)
  final _liveError = RxnString();
  String? get liveError => _liveError.value;
  set liveError(String? v) => _liveError.value = v;

  /// Realtime 연결 상태 (true면 실시간 구독 활성)
  final _isRealtimeConnected = false.obs;
  bool get isRealtimeConnected => _isRealtimeConnected.value;

  /// 마지막 스코어 변경이 발생한 매치 id → 변경 시각.
  /// View에서 카드별 펄스 애니메이션 트리거에 사용한다.
  final RxMap<int, DateTime> scoreBumpAt = <int, DateTime>{}.obs;

  // ── 오늘 경기 상태 ──────────────────────────────────────────

  /// 오늘 경기 결과 목록 (match_time ASC).
  final _todayResults = <TodayMatchResponse>[].obs;
  List<TodayMatchResponse> get todayResults => _todayResults;

  /// 오늘 예정 경기 목록 (match_time ASC).
  final _todayUpcoming = <TodayMatchResponse>[].obs;
  List<TodayMatchResponse> get todayUpcoming => _todayUpcoming;

  /// 결과+예정을 합친 단일 캐러셀용 목록.
  ///
  /// 각 그룹(결과 / 예정) 내부에서:
  /// 1. 한국 선수 포함 경기를 앞으로 보내고,
  /// 2. 동률은 경기 시간 오름차순으로 정렬한다.
  /// 시간이 없는 항목은 그룹 내 뒤로 보낸다.
  List<TodayMatchResponse> get todayMerged {
    int compareEntries(TodayMatchResponse a, TodayMatchResponse b) {
      final ka = a.hasKoreanPlayer ? 0 : 1;
      final kb = b.hasKoreanPlayer ? 0 : 1;
      if (ka != kb) return ka.compareTo(kb);
      final da = a.matchDateTime;
      final db = b.matchDateTime;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }

    final results = [..._todayResults]..sort(compareEntries);
    final upcoming = [..._todayUpcoming]..sort(compareEntries);
    return [...results, ...upcoming];
  }

  /// 오늘 경기 에러 메시지 (null이면 정상).
  final _todayError = RxnString();
  String? get todayError => _todayError.value;

  /// 오늘 경기 inflight 토큰 (race condition 방지).
  int _todayInflightToken = 0;

  // ── 남은 대회(진행중/진행예정) 상태 ───────────────────────────

  /// 진행중/진행예정 대회 목록 (start_date ASC, 한국 선수 정보 포함)
  final _activeTournaments = <ActiveTournamentResponse>[].obs;
  List<ActiveTournamentResponse> get activeTournaments => _activeTournaments;

  /// 남은 대회 에러 메시지 (null이면 정상)
  final _activeTournamentsError = RxnString();
  String? get activeTournamentsError => _activeTournamentsError.value;

  /// 남은 대회 inflight 토큰 (race condition 방지)
  int _activeTournamentsToken = 0;

  // ── 카드뉴스 상태 ────────────────────────────────────────────

  /// 카드뉴스 목록 (최신순, 무한 스크롤로 누적)
  final _newsCards = <NewsCardResponse>[].obs;
  List<NewsCardResponse> get newsCards => _newsCards;

  /// 첫 페이지 조회 진행 중 여부 (loadMore 동시 호출 가드용)
  bool _isNewsFetching = false;

  /// 다음 페이지(더보기) 로딩 중 여부
  final _isNewsLoadingMore = false.obs;
  bool get isNewsLoadingMore => _isNewsLoadingMore.value;

  /// 카드뉴스 에러 메시지 (null이면 정상)
  final _newsError = RxnString();
  String? get newsError => _newsError.value;

  /// 마지막으로 로드한 카드뉴스 페이지 번호
  int _newsPage = 0;

  /// 더 불러올 페이지가 남았는지 여부
  final _hasMoreNews = true.obs;
  bool get hasMoreNews => _hasMoreNews.value;

  /// 카드뉴스 inflight 토큰 (race condition 방지)
  int _newsInflightToken = 0;

  /// 선택된 뉴스 소스 필터 slug (null이면 전체)
  final _selectedNewsSource = RxnString();
  String? get selectedNewsSource => _selectedNewsSource.value;

  /// 필터 칩에 노출할 뉴스 소스 slug 목록 (신규 소스 크롤러 추가 시 여기에 등록)
  static const List<String> newsSources = ['badmintonplanet.com'];

  /// slug → 한글 표시명. 미등록 slug는 slug 그대로 반환.
  static String newsSourceLabelOf(String? slug) => switch (slug) {
        'badmintonplanet.com' => '배드민턴 플래닛',
        _ => slug ?? '',
      };

  /// 진행 중인 inflight 요청 토큰 (race condition 방지)
  int _inflightToken = 0;

  /// Realtime 채널
  RealtimeChannel? _liveChannel;

  @override
  void onInit() {
    super.onInit();
    fetchActiveTournaments();
    fetchLiveMatches();
    fetchTodayMatches();
    fetchNewsCards();
    subscribeRealtime();
  }

  @override
  void onClose() {
    unsubscribeRealtime();
    super.onClose();
  }

  /// 라이브 매치 목록을 조회한다.
  Future<void> fetchLiveMatches() async {
    final token = ++_inflightToken;

    try {
      liveError = null;

      final response = await _liveMatchRepository.getLiveMatches();

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _inflightToken) return;

      _liveMatches.assignAll(response.matches ?? const <LiveMatchResponse>[]);
    } catch (e) {
      if (token != _inflightToken) return;
      log('HomeController.fetchLiveMatches error: $e');
      liveError = '라이브 매치 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      _liveMatches.clear();
    } finally {
      if (token == _inflightToken) {
        _onApiLoaded();
      }
    }
  }

  /// Pull-to-refresh / 재시도 버튼용 — 남은 대회 + 라이브 매치 + 오늘 경기 + 카드뉴스 재호출.
  Future<void> refreshLiveMatches() async {
    await Future.wait([
      fetchActiveTournaments(),
      fetchLiveMatches(),
      fetchTodayMatches(),
      fetchNewsCards(),
    ]);
  }

  // ── 오늘 경기 조회 ──────────────────────────────────────────

  /// 오늘 경기(결과/예정) 목록을 조회한다.
  ///
  /// 빈 응답은 에러가 아니라 정상으로 처리한다.
  Future<void> fetchTodayMatches() async {
    final token = ++_todayInflightToken;

    try {
      _todayError.value = null;

      final response = await _todayMatchRepository.getTodayMatches();

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _todayInflightToken) return;

      _todayResults.assignAll(response.results ?? const <TodayMatchResponse>[]);
      _todayUpcoming.assignAll(
        response.upcoming ?? const <TodayMatchResponse>[],
      );
    } catch (e) {
      if (token != _todayInflightToken) return;
      log('HomeController.fetchTodayMatches error: $e');
      _todayError.value = '오늘 경기 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      _todayResults.clear();
      _todayUpcoming.clear();
    } finally {
      if (token == _todayInflightToken) {
        _onApiLoaded();
      }
    }
  }

  /// 진행중/진행예정 "남은 대회" 목록을 조회한다(한국 선수 참여 정보 포함).
  Future<void> fetchActiveTournaments() async {
    final token = ++_activeTournamentsToken;

    try {
      _activeTournamentsError.value = null;

      final response = await _tournamentRepository.getActiveTournamentsKr();

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _activeTournamentsToken) return;
      _activeTournaments.assignAll(response.tournaments);
    } catch (e) {
      if (token != _activeTournamentsToken) return;
      log('HomeController.fetchActiveTournaments error: $e');
      _activeTournamentsError.value = '대회 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      _activeTournaments.clear();
    } finally {
      if (token == _activeTournamentsToken) {
        _onApiLoaded();
      }
    }
  }

  // ── 카드뉴스 조회 ────────────────────────────────────────────

  /// 카드뉴스 첫 페이지를 조회한다(기존 목록을 교체).
  ///
  /// pull-to-refresh / 최초 진입 / 재시도에 사용한다.
  Future<void> fetchNewsCards() async {
    final token = ++_newsInflightToken;

    try {
      _isNewsFetching = true;
      _newsError.value = null;

      final response = await _newsCardRepository.getNewsCards(
        page: 1,
        perPage: _newsPageSize,
        source: _selectedNewsSource.value,
      );

      // race condition 가드: 더 새로운 요청(필터 변경 등)이 발생했으면 결과 무시
      if (token != _newsInflightToken) return;

      _newsCards.assignAll(response.cards);
      _newsPage = response.page ?? 1;
      _hasMoreNews.value = _computeHasMore(response);
    } catch (e) {
      if (token != _newsInflightToken) return;
      log('HomeController.fetchNewsCards error: $e');
      _newsError.value = '뉴스를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      _newsCards.clear();
      _hasMoreNews.value = false;
    } finally {
      if (token == _newsInflightToken) {
        _isNewsFetching = false;
        _onApiLoaded();
      }
    }
  }

  /// 뉴스 소스 필터를 변경한다. 같은 값이면 no-op, 변경 시 첫 페이지부터 재로드.
  ///
  /// [source] null이면 전체.
  Future<void> changeNewsSource(String? source) async {
    if (_selectedNewsSource.value == source) return;
    _selectedNewsSource.value = source;
    await fetchNewsCards();
  }

  /// 다음 페이지를 조회해 기존 목록 뒤에 누적한다(무한 스크롤).
  ///
  /// 이미 로딩 중이거나 더 불러올 페이지가 없으면 no-op.
  Future<void> loadMoreNewsCards() async {
    if (_isNewsFetching || _isNewsLoadingMore.value || !_hasMoreNews.value) {
      return;
    }

    final token = _newsInflightToken;
    final nextPage = _newsPage + 1;

    try {
      _isNewsLoadingMore.value = true;

      final response = await _newsCardRepository.getNewsCards(
        page: nextPage,
        perPage: _newsPageSize,
        source: _selectedNewsSource.value,
      );

      // fetchNewsCards(refresh)가 끼어들었으면 더보기 결과는 버린다.
      if (token != _newsInflightToken) return;

      _newsCards.addAll(response.cards);
      _newsPage = response.page ?? nextPage;
      _hasMoreNews.value = _computeHasMore(response);
    } catch (e) {
      log('HomeController.loadMoreNewsCards error: $e');
      // 더보기 실패는 조용히 무시(다음 스크롤에서 재시도 가능). 더 시도하지 않도록 막지 않는다.
    } finally {
      if (token == _newsInflightToken) {
        _isNewsLoadingMore.value = false;
      }
    }
  }

  /// 응답의 total/count 기준으로 다음 페이지 존재 여부를 계산한다.
  bool _computeHasMore(GetNewsCardsResponse response) {
    final count = response.count ?? response.cards.length;
    // 이번 페이지가 페이지 크기보다 적게 왔으면 마지막 페이지.
    if (count < (response.perPage ?? _newsPageSize)) return false;
    // total 정보가 있으면 누적 개수로 판단.
    final total = response.total;
    if (total != null) return _newsCards.length < total;
    return count > 0;
  }

  // ── Realtime 구독 ────────────────────────────────────────────

  /// `bwf_live_matches` 테이블 변경을 구독한다.
  ///
  /// - INSERT: 새 라이브 매치가 생기면 목록에 추가
  /// - UPDATE: 스코어/상태 변경 시 해당 row 교체 + 스코어 diff면 펄스 트리거
  /// - DELETE: 라이브 종료된 매치 제거
  void subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      _liveChannel = client
          .channel('public:bwf_live_matches')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bwf_live_matches',
            callback: _onLiveMatchChange,
          )
          .subscribe((status, error) {
            _isRealtimeConnected.value =
                status == RealtimeSubscribeStatus.subscribed;
            if (error != null) {
              log('HomeController realtime subscribe error: $error');
            }
          });
    } catch (e) {
      log('HomeController._subscribeRealtime error: $e');
      _isRealtimeConnected.value = false;
    }
  }

  void unsubscribeRealtime() {
    final ch = _liveChannel;
    if (ch == null) return;
    try {
      Supabase.instance.client.removeChannel(ch);
    } catch (e) {
      log('HomeController._unsubscribeRealtime error: $e');
    }
    _liveChannel = null;
    _isRealtimeConnected.value = false;
  }

  void _onLiveMatchChange(PostgresChangePayload payload) {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          // _handleInsert(payload.newRecord);
          fetchLiveMatches();
          break;
        case PostgresChangeEvent.update:
          _handleUpdate(payload.oldRecord, payload.newRecord);
          break;
        case PostgresChangeEvent.delete:
          _handleDelete(payload.oldRecord);
          break;
        case PostgresChangeEvent.all:
          // 실제 페이로드는 insert/update/delete 중 하나로만 들어옴
          break;
      }
    } catch (e) {
      log('HomeController._onLiveMatchChange error: $e');
    }
  }

  /// Realtime INSERT 처리.
  ///
  /// 기존 매치가 이미 목록에 있으면(예: 초기 fetch로 로드된 row) 다른 필드는
  /// 그대로 두고 `score`만 갱신한다. 목록에 없으면 전체 파싱해 새로 추가한다.
  void _handleInsert(Map<String, dynamic> row) {
    if (row.isEmpty) return;
    final id = _extractId(row);
    if (id == null) return;

    final idx = _liveMatches.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final existing = _liveMatches[idx];
      final prevScore = existing.score;
      existing.applyScoreFromJson(row);
      // RxList에 변경 통지 (같은 인스턴스 mutation은 자동 감지 안 됨)
      _liveMatches[idx] = existing;
      if ((prevScore ?? '') != (existing.score ?? '')) {
        scoreBumpAt[id] = DateTime.now();
      }
    } else {
      final parsed = LiveMatchResponse.fromJson(row);
      _liveMatches.add(parsed);
    }
  }

  /// Realtime UPDATE 처리.
  ///
  /// 기존 객체의 다른 필드(팀명/대회/아바타 등)는 초기 fetch 값을 유지하고
  /// `score` 필드만 갱신한다. 라이브 종료(status 변화)는 newRow를 직접 검사해 판단.
  void _handleUpdate(Map<String, dynamic> oldRow, Map<String, dynamic> newRow) {
    if (newRow.isEmpty) return;
    final id = _extractId(newRow);
    if (id == null) return;

    // 서버가 DELETE 대신 status 변경(예: tournament_status='completed')으로
    // 라이브를 끝내는 경우, UPDATE에서 이 케이스를 잡아 리스트에서 제거한다.
    if (!_isStillLiveJson(newRow)) {
      _liveMatches.removeWhere((m) => m.id == id);
      scoreBumpAt.remove(id);
      return;
    }

    final idx = _liveMatches.indexWhere((m) => m.id == id);
    if (idx < 0) {
      // 새 라이브 매치가 update로 들어온 경우(드물지만 가드) — 전체 파싱.
      final parsed = LiveMatchResponse.fromJson(newRow);
      _liveMatches.add(parsed);
      scoreBumpAt[id] = DateTime.now();
      return;
    }

    final existing = _liveMatches[idx];
    final prevScore = existing.score;
    existing.applyScoreFromJson(newRow);
    // RxList에 변경 통지 (같은 인스턴스 mutation은 자동 감지 안 됨)
    _liveMatches[idx] = existing;

    if ((prevScore ?? '') != (existing.score ?? '')) {
      scoreBumpAt[id] = DateTime.now();
    }
  }

  int? _extractId(Map<String, dynamic> row) {
    final v = row['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  void _handleDelete(Map<String, dynamic> oldRow) {
    final oldId = oldRow['id'];
    final id =
        oldId is int
            ? oldId
            : (oldId is num ? oldId.toInt() : int.tryParse('${oldId ?? ''}'));
    if (id != null) {
      _liveMatches.removeWhere((m) => m.id == id);
      scoreBumpAt.remove(id);
      return;
    }

    // REPLICA IDENTITY가 DEFAULT인 경우 oldRow에 PK만 들어와야 정상인데,
    // 그조차 비어있다면 publication/replica identity 설정이 누락된 것.
    // 안전망: 다음 polling 때 재동기화되도록 전체 재조회.
    log(
      'HomeController._handleDelete: oldRow has no usable id — falling back to full refresh',
    );
    fetchLiveMatches();
  }

  /// Realtime payload(row Map)가 여전히 라이브 상태인지 판단.
  ///
  /// 모델 전체를 다시 파싱하지 않고 row의 status 필드만 검사해서
  /// 라이브 종료 케이스(`tournament_status` 변경, `match_status` 종료 키워드)를 잡는다.
  /// 일부 row는 tournament_status=null이고 match_status로만 종료를 표시하므로
  /// 두 필드를 모두 본다.
  bool _isStillLiveJson(Map<String, dynamic> row) {
    final t = (row['tournament_status']?.toString() ?? '').toLowerCase().trim();
    if (t.isNotEmpty && t != 'live') return false;

    final s = (row['match_status']?.toString() ?? '').toLowerCase().trim();
    if (s.contains('complete') ||
        s.contains('finish') ||
        s.contains('result') ||
        s.contains('done') ||
        s.contains('cancel') ||
        s.contains('postpone')) {
      return false;
    }
    return true;
  }
}
