import 'package:get/get.dart';

import '../../../data/repositories/tournament_repository.dart';
import '../controllers/match_controller.dart';

class MatchBinding implements Bindings {
  @override
  void dependencies() {
    // 대회 목록 조회 레포지토리 (Edge Function 호출 담당)
    Get.lazyPut<TournamentRepository>(() => TournamentRepository());

    // 경기 화면 컨트롤러
    Get.lazyPut<MatchController>(() => MatchController());
  }
}
