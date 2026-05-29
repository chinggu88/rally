import 'package:get/get.dart';

import '../../../data/repositories/player_repository.dart';
import '../controllers/player_detail_controller.dart';

class PlayerDetailBinding implements Bindings {
  @override
  void dependencies() {
    // 선수 상세 조회 레포지토리 (Edge Function 호출 담당)
    Get.lazyPut<PlayerRepository>(() => PlayerRepository());

    // 선수 상세 화면 컨트롤러
    Get.lazyPut<PlayerDetailController>(() => PlayerDetailController());
  }
}
