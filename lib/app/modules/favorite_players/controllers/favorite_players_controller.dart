import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/favorite_player_response.dart';
import '../../../data/repositories/favorite_player_repository.dart';
import '../../../routes/app_routes.dart';
import '../../player/controllers/player_detail_controller.dart';

/// 좋아하는 선수 목록 화면 컨트롤러.
class FavoritePlayersController extends GetxController {
  final FavoritePlayerRepository _repository =
      Get.find<FavoritePlayerRepository>();

  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final _players = <FavoritePlayerResponse>[].obs;
  List<FavoritePlayerResponse> get players => _players;

  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      _isLoading.value = true;
      _errorMessage.value = null;
      final list = await _repository.listFavorites();
      _players.assignAll(list);
    } catch (e) {
      log('FavoritePlayersController.load error: $e');
      _errorMessage.value = '목록을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> remove(int playerId) async {
    try {
      await _repository.removeFavorite(playerId);
      _players.removeWhere((p) => p.playerId == playerId);
    } catch (e) {
      log('FavoritePlayersController.remove error: $e');
      Get.snackbar('삭제 실패', '잠시 후 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 항목 탭 → 선수 상세로 이동 (스냅샷 컨텍스트 전달).
  void openDetail(FavoritePlayerResponse p) {
    Get.toNamed(
      Routes.PLAYER_DETAIL,
      arguments: <String, dynamic>{
        PlayerDetailController.argId: p.playerId,
        PlayerDetailController.argPlayerName: p.playerName,
        PlayerDetailController.argCountryCode: p.countryCode,
      },
    );
  }
}
