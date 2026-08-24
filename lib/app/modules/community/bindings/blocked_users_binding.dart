import 'package:get/get.dart';

import '../../../data/repositories/community_moderation_repository.dart';
import '../controllers/blocked_users_controller.dart';

/// `/community/blocked-users` 라우트 바인딩.
///
/// 내정보 탭에서 진입하므로 커뮤니티 바인딩을 거치지 않을 수 있다.
/// `fenix: true` 라 `AppBinding` 이 이미 등록해 뒀어도 기존 인스턴스를
/// 덮지 않는다.
class BlockedUsersBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CommunityModerationRepository>(
      () => CommunityModerationRepository(),
      fenix: true,
    );
    Get.lazyPut<BlockedUsersController>(() => BlockedUsersController());
  }
}
