import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/player_response.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../routes/app_routes.dart';
import 'player_detail_controller.dart';

/// 선수(BWF 랭킹) 화면 컨트롤러.
///
/// Supabase Edge Function `get-players` 를 호출해 종목별(MS/WS/MD/WD/XD)
/// BWF 랭킹 선수 목록을 조회한다. 진입 시 기본 카테고리(`MS`)로 1회 로드하고,
/// 카테고리 변경/새로고침/재시도를 지원한다.
class PlayerController extends GetxController {
  /// Singleton accessor
  static PlayerController get to => Get.find();

  /// 지원하는 카테고리 코드 목록 (BWF 5종)
  static const List<String> categories = <String>[
    'MS', // Men's Singles
    'WS', // Women's Singles
    'MD', // Men's Doubles
    'WD', // Women's Doubles
    'XD', // Mixed Doubles
  ];

  /// 카테고리 코드 → 한국어 라벨 매핑
  static const Map<String, String> _categoryLabelsKo = <String, String>{
    'MS': '남자 단식',
    'WS': '여자 단식',
    'MD': '남자 복식',
    'WD': '여자 복식',
    'XD': '혼합 복식',
  };

  /// 카테고리 코드 → 영문 라벨 매핑 (Stitch 디자인 톤)
  static const Map<String, String> _categoryLabelsEn = <String, String>{
    'MS': "Men's Singles",
    'WS': "Women's Singles",
    'MD': "Men's Doubles",
    'WD': "Women's Doubles",
    'XD': 'Mixed Doubles',
  };

  /// 선수 목록 조회 레포지토리 (Supabase Edge Function 호출 담당)
  final PlayerRepository _playerRepository = PlayerRepository();

  /// API 요청 중 로딩 상태 여부
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => _isLoading.value = val;

  /// 화면에 표시할 BWF 랭킹 선수 목록 (rank 오름차순으로 정렬됨)
  final _players = <PlayerResponse>[].obs;
  List<PlayerResponse> get players => _players;
  set players(List<PlayerResponse> val) => _players.assignAll(val);

  /// 에러 메시지 (null이면 정상 상태로 간주)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => _errorMessage.value = val;

  /// 현재 선택된 카테고리 (기본값: `'MS'`)
  final _selectedCategory = 'MS'.obs;
  String get selectedCategory => _selectedCategory.value;
  set selectedCategory(String val) => _selectedCategory.value = val;

  /// 한 페이지에 가져올 선수 수 (Edge Function `get-players` 기본값과 일치)
  static const int pageSize = 30;

  /// 다음 페이지 요청에 사용할 offset (현재까지 받은 선수 수)
  int _offset = 0;

  /// 다음 페이지가 더 있는지 여부 (서버 `has_more` 또는 길이 < pageSize 로 판단)
  final _hasMore = true.obs;
  bool get hasMore => _hasMore.value;

  /// 추가 페이지 로딩 중 여부 (첫 로드와 분리)
  final _isLoadingMore = false.obs;
  bool get isLoadingMore => _isLoadingMore.value;

  /// 진행 중인 inflight 요청 토큰 (race condition 방지)
  int _inflightToken = 0;

  /// loadMore 전용 토큰 — 첫 로드/카테고리 변경/리프레시 시 증가시켜
  /// 진행 중이던 loadMore 결과가 새 리스트에 잘못 append 되지 않도록 방어한다.
  int _loadMoreToken = 0;

  /// 탭 진입 시 View에 스크롤 상단으로 리셋하라는 신호 (값이 증가할 때마다 트리거).
  /// View는 `ever(resetSignal, ...)`로 listen 한다.
  final RxInt resetSignal = 0.obs;

  /// 카테고리 코드의 한국어 라벨 반환 (없으면 코드 그대로)
  static String labelKoOf(String code) => _categoryLabelsKo[code] ?? code;

  /// 카테고리 코드의 영문 라벨 반환 (없으면 코드 그대로)
  static String labelEnOf(String code) => _categoryLabelsEn[code] ?? code;

  @override
  void onInit() {
    super.onInit();
    fetchPlayers();
  }

  /// 선수 목록 첫 페이지(0~pageSize-1)를 조회한다.
  ///
  /// 호출 시점에 진행 중이던 loadMore는 토큰 가드로 무효화되며,
  /// 페이지 상태(`_offset`, `_hasMore`)는 초기화된다.
  ///
  /// [category] 조회할 카테고리. null이면 현재 `selectedCategory`를 사용한다.
  Future<void> fetchPlayers({String? category}) async {
    final targetCategory = category ?? selectedCategory;
    final token = ++_inflightToken;
    // 진행 중인 loadMore가 새 리스트에 결과를 append 하지 못하도록 무효화
    _loadMoreToken++;
    _offset = 0;
    _hasMore.value = true;

    try {
      isLoading = true;
      errorMessage = null;

      final response = await _playerRepository.getPlayers(
        category: targetCategory,
        limit: pageSize,
        offset: 0,
      );

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _inflightToken) {
        return;
      }

      final fetched = (response.players ?? const <PlayerResponse>[]).toList();

      // rank 오름차순 정렬 (null은 가장 뒤로)
      // 서버가 rank ASC + range 로 보장하지만, 방어적으로 한 번 정렬해 둔다.
      fetched.sort((a, b) {
        final ar = a.rank;
        final br = b.rank;
        if (ar == null && br == null) return 0;
        if (ar == null) return 1;
        if (br == null) return -1;
        return ar.compareTo(br);
      });

      players = fetched;
      _offset = fetched.length;
      final hasMoreFromServer = response.hasMore;
      if (hasMoreFromServer != null) {
        _hasMore.value = hasMoreFromServer;
      } else {
        _hasMore.value = fetched.length >= pageSize;
      }

      final returnedCategory = response.category;
      if (returnedCategory != null && returnedCategory.isNotEmpty) {
        selectedCategory = returnedCategory;
      } else {
        selectedCategory = targetCategory;
      }
    } catch (e) {
      if (token != _inflightToken) return;
      log('PlayerController.fetchPlayers error: $e');
      errorMessage = '선수 랭킹을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      players = const <PlayerResponse>[];
      _offset = 0;
      _hasMore.value = false;
    } finally {
      if (token == _inflightToken) {
        isLoading = false;
      }
    }
  }

  /// 다음 페이지를 추가로 로드해 기존 리스트에 append 한다.
  ///
  /// 이미 추가 로딩 중이거나, 끝에 도달했거나, 첫 페이지 로딩/에러 상태면 즉시 종료.
  /// 실패는 silent — `_hasMore`는 유지되어 다음 스크롤에서 자연 재시도된다.
  Future<void> loadMore() async {
    if (_isLoadingMore.value) return;
    if (!_hasMore.value) return;
    if (_isLoading.value) return;
    if (errorMessage != null) return;

    final fetchTokenAtStart = _inflightToken;
    final myToken = ++_loadMoreToken;
    final targetCategory = selectedCategory;
    final requestOffset = _offset;

    _isLoadingMore.value = true;
    try {
      final response = await _playerRepository.getPlayers(
        category: targetCategory,
        limit: pageSize,
        offset: requestOffset,
      );

      // 가드: 그 사이 fetchPlayers(카테고리 변경/리프레시/탭 진입)가 발생했으면 무시
      if (fetchTokenAtStart != _inflightToken) return;
      if (myToken != _loadMoreToken) return;

      final fetched = (response.players ?? const <PlayerResponse>[]).toList();
      if (fetched.isNotEmpty) {
        _players.addAll(fetched);
        _offset += fetched.length;
      }

      final hasMoreFromServer = response.hasMore;
      if (hasMoreFromServer != null) {
        _hasMore.value = hasMoreFromServer;
      } else {
        _hasMore.value = fetched.length >= pageSize;
      }
    } catch (e) {
      log('PlayerController.loadMore error: $e');
      // silent: hasMore 유지 → 다음 스크롤에서 자연스럽게 재시도 가능
    } finally {
      if (myToken == _loadMoreToken) {
        _isLoadingMore.value = false;
      }
    }
  }

  /// Pull-to-refresh / 재시도 버튼용 — 현재 `selectedCategory`로 재호출한다.
  Future<void> refreshPlayers() async {
    await fetchPlayers(category: selectedCategory);
  }

  /// 선수 탭 진입 시 호출 — 스크롤 리셋 신호를 보내고 첫 페이지를 다시 로드한다.
  ///
  /// IndexedStack 구조에서 PlayerView 인스턴스가 살아있기 때문에 진입 시점에
  /// 명시적으로 30건 리셋이 필요하다. 기존 리스트를 비우고 시작해
  /// View가 로딩 인디케이터(`isLoading && players.isEmpty`)를 표시하도록 한다.
  Future<void> reloadFromTab() async {
    resetSignal.value++;
    players = const <PlayerResponse>[];
    await fetchPlayers(category: selectedCategory);
  }

  /// 카테고리를 변경하고 목록을 다시 불러온다.
  ///
  /// [category] 새로 선택된 카테고리. 동일 카테고리 재선택 시 no-op.
  /// 5개 허용 카테고리(MS/WS/MD/WD/XD)가 아니면 무시한다.
  Future<void> changeCategory(String category) async {
    if (category == selectedCategory) return;
    if (!categories.contains(category)) {
      log('PlayerController.changeCategory: unsupported category=$category');
      return;
    }
    selectedCategory = category;
    await fetchPlayers(category: category);
  }

  /// 선수 카드 탭 시 호출 — 상세 화면(`Routes.PLAYER_DETAIL`)으로 전이한다.
  ///
  /// 상세 API(`get-player`)는 `bwf_players.id`(= `player1_id`/`player2_id`)로
  /// 조회한다. 상세에 없는 랭킹 정보(rank/category)와 로드 전 폴백
  /// (이름/국가)을 arguments로 함께 넘긴다.
  /// 참고 Stitch 화면: projects/307006344264476289/screens/b3ae5f6699f448e5bae6703091c35026
  void openPlayerDetail(PlayerResponse p) {
    final detailId = p.detailId;
    log(
      'PlayerController.openPlayerDetail: rank=${p.rank}, '
      'name=${p.playerName}, country=${p.countryCode}, id=$detailId',
    );

    Get.toNamed(
      Routes.PLAYER_DETAIL,
      arguments: <String, dynamic>{
        PlayerDetailController.argId: detailId,
        PlayerDetailController.argRank: p.rank,
        PlayerDetailController.argCategory: selectedCategory,
        PlayerDetailController.argPlayerName: p.playerName,
        PlayerDetailController.argCountryCode: p.countryCode,
      },
    );
  }

  /// 복식 카드에서 두 선수 중 한 명을 탭했을 때 호출 — 해당 선수의 상세로 전이한다.
  ///
  /// [playerId] 는 `player1Id` 또는 `player2Id` 중 탭된 선수의 id.
  /// [playerName] 은 분리된 단일 선수 이름(예: `"Dechapol PUAVARANUKROH"`).
  /// 상세 진입 키만 다르고, 랭킹/종목/국가 컨텍스트는 동일하게 전달한다.
  void openDoublesPlayerDetail({
    required PlayerResponse p,
    required int? playerId,
    required String? playerName,
  }) {
    log(
      'PlayerController.openDoublesPlayerDetail: rank=${p.rank}, '
      'name=$playerName, country=${p.countryCode}, id=$playerId',
    );

    Get.toNamed(
      Routes.PLAYER_DETAIL,
      arguments: <String, dynamic>{
        PlayerDetailController.argId: playerId,
        PlayerDetailController.argRank: p.rank,
        PlayerDetailController.argCategory: selectedCategory,
        PlayerDetailController.argPlayerName: playerName,
        PlayerDetailController.argCountryCode: p.countryCode,
      },
    );
  }
}
