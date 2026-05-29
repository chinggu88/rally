import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/player_detail_response.dart';
import '../../../data/repositories/player_repository.dart';

/// 선수 상세 프로필(매거진) 화면 컨트롤러.
///
/// 리스트 화면에서 [Get.toNamed] 의 `arguments` 로 전달된 랭킹 컨텍스트
/// (`id`/`rank`/`category`/`playerName`/`countryCode`)를 보존하고,
/// Supabase Edge Function `get-player` 로 풍부한 프로필을 조회해 병합한다.
///
/// `bwf_players` 데이터가 아직 없을 수 있으므로(404), 상세가 비어도
/// 리스트에서 받은 컨텍스트로 히어로/퀵스탯을 그릴 수 있도록 설계한다.
class PlayerDetailController extends GetxController {
  /// arguments 키 — 상세 조회용 `bwf_players.id`
  static const String argId = 'id';

  /// arguments 키 — 세계 랭킹 (리스트 컨텍스트)
  static const String argRank = 'rank';

  /// arguments 키 — 종목 코드 (MS/WS/MD/WD/XD)
  static const String argCategory = 'category';

  /// arguments 키 — 선수명 (상세 로드 전 폴백)
  static const String argPlayerName = 'playerName';

  /// arguments 키 — 국가 코드 (상세 로드 전 폴백)
  static const String argCountryCode = 'countryCode';

  final PlayerRepository _playerRepository = Get.find<PlayerRepository>();

  /// 상세 조회 대상 id (null이면 조회 불가 → notFound 처리)
  int? _playerId;
  int? get playerId => _playerId;

  /// 리스트에서 받은 랭킹 (상세에 없는 정보)
  int? _rank;
  int? get rank => _rank;

  /// 리스트에서 받은 종목 코드
  String? _category;
  String? get category => _category;

  /// 상세 로드 전/실패 시 폴백 선수명
  String? _fallbackName;
  String? get fallbackName => _fallbackName;

  /// 상세 로드 전/실패 시 폴백 국가 코드
  String? _fallbackCountryCode;
  String? get fallbackCountryCode => _fallbackCountryCode;

  /// API 요청 중 로딩 상태 여부
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => _isLoading.value = val;

  /// 조회된 상세 프로필 (null이면 미로드 또는 미존재)
  final _detail = Rxn<PlayerDetailResponse>();
  PlayerDetailResponse? get detail => _detail.value;
  set detail(PlayerDetailResponse? val) => _detail.value = val;

  /// 상세 데이터가 존재하지 않음(404 등) 여부
  final _notFound = false.obs;
  bool get notFound => _notFound.value;
  set notFound(bool val) => _notFound.value = val;

  /// 에러 메시지 (null이면 정상 상태로 간주)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => _errorMessage.value = val;

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    fetchDetail();
  }

  /// 네비게이션 arguments 파싱 — Map 형태를 기대하되, 누락에 안전하게 처리.
  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      _playerId = _asInt(args[argId]);
      _rank = _asInt(args[argRank]);
      _category = args[argCategory] as String?;
      _fallbackName = (args[argPlayerName] as String?)?.trim();
      _fallbackCountryCode = (args[argCountryCode] as String?)?.trim();
    } else if (args is int) {
      // id만 전달된 단순 케이스
      _playerId = args;
    }
  }

  /// 상세 프로필을 조회한다.
  Future<void> fetchDetail() async {
    final id = _playerId;
    if (id == null || id <= 0) {
      // 식별자가 없으면 조회 불가 — 리스트 컨텍스트만으로 표시
      notFound = true;
      isLoading = false;
      return;
    }

    try {
      isLoading = true;
      errorMessage = null;
      notFound = false;

      final response = await _playerRepository.getPlayer(id: id);
      final player = response.player;

      if (player == null) {
        detail = null;
        notFound = true;
      } else {
        detail = player;
        notFound = false;
      }
    } catch (e) {
      log('PlayerDetailController.fetchDetail error: $e');
      errorMessage = '선수 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      isLoading = false;
    }
  }

  /// 재시도 버튼용 — 상세를 다시 불러온다.
  Future<void> refreshDetail() async {
    await fetchDetail();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
