import 'package:get/get.dart';

import '../../../data/repositories/tournament_repository.dart';
import '../controllers/tournament_participants_controller.dart';

/// 대회 참가 선수 화면 바인딩.
///
/// 진입 경로 두 가지 모두 안전하게 동작하도록 [TournamentRepository]를
/// `fenix: true`로 lazyPut 한다 (대회 상세에서 push 진입 / 딥링크로 직접 진입).
class TournamentParticipantsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TournamentRepository>(
      () => TournamentRepository(),
      fenix: true,
    );
    Get.lazyPut<TournamentParticipantsController>(
      () => TournamentParticipantsController(),
    );
  }
}
