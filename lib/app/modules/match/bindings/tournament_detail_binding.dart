import 'package:get/get.dart';

import '../../../data/repositories/tournament_repository.dart';
import '../controllers/tournament_detail_controller.dart';

class TournamentDetailBinding implements Bindings {
  @override
  void dependencies() {
    // 대회 상세 조회 레포지토리 (Edge Function 호출 담당)
    Get.lazyPut<TournamentRepository>(() => TournamentRepository());

    // 대회 상세 화면 컨트롤러
    Get.lazyPut<TournamentDetailController>(
      () => TournamentDetailController(),
    );
  }
}
