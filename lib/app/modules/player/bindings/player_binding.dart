import 'package:get/get.dart';

import '../../../data/repositories/player_repository.dart';
import '../controllers/player_controller.dart';

class PlayerBinding implements Bindings {
  @override
  void dependencies() {
    // 선수 목록 조회 레포지토리 (Edge Function 호출 담당)
    Get.lazyPut<PlayerRepository>(() => PlayerRepository());

    // 선수 화면 컨트롤러
    Get.lazyPut<PlayerController>(() => PlayerController());
  }
}
