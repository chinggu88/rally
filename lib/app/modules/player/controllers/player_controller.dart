import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/player_response.dart';
import '../../../data/repositories/player_repository.dart';

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

  /// 진행 중인 inflight 요청 토큰 (race condition 방지)
  int _inflightToken = 0;

  /// 카테고리 코드의 한국어 라벨 반환 (없으면 코드 그대로)
  static String labelKoOf(String code) =>
      _categoryLabelsKo[code] ?? code;

  /// 카테고리 코드의 영문 라벨 반환 (없으면 코드 그대로)
  static String labelEnOf(String code) =>
      _categoryLabelsEn[code] ?? code;

  @override
  void onInit() {
    super.onInit();
    fetchPlayers();
  }

  /// 선수 목록을 조회한다.
  ///
  /// [category] 조회할 카테고리. null이면 현재 `selectedCategory`를 사용한다.
  Future<void> fetchPlayers({String? category}) async {
    final targetCategory = category ?? selectedCategory;
    final token = ++_inflightToken;

    try {
      isLoading = true;
      errorMessage = null;

      final response = await _playerRepository.getPlayers(
        category: targetCategory,
      );

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _inflightToken) {
        return;
      }

      final fetched = (response.players ?? const <PlayerResponse>[]).toList();

      // rank 오름차순 정렬 (null은 가장 뒤로)
      fetched.sort((a, b) {
        final ar = a.rank;
        final br = b.rank;
        if (ar == null && br == null) return 0;
        if (ar == null) return 1;
        if (br == null) return -1;
        return ar.compareTo(br);
      });

      players = fetched;
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
    } finally {
      if (token == _inflightToken) {
        isLoading = false;
      }
    }
  }

  /// Pull-to-refresh / 재시도 버튼용 — 현재 `selectedCategory`로 재호출한다.
  Future<void> refreshPlayers() async {
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

  /// 선수 카드 탭 시 호출 — 현재는 placeholder.
  ///
  /// TODO(player-detail): 추후 별도 태스크로 추가될 `Routes.PLAYER_DETAIL`로 전이.
  /// 참고 Stitch 화면: projects/307006344264476289/screens/b3ae5f6699f448e5bae6703091c35026
  void openPlayerDetail(PlayerResponse p) {
    log('PlayerController.openPlayerDetail: rank=${p.rank}, '
        'name=${p.playerName}, country=${p.countryCode}');
    // 현재는 무동작 (placeholder)
  }
}
