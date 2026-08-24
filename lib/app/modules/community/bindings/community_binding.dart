import 'package:get/get.dart';

import '../../../data/repositories/community_moderation_repository.dart';
import '../../../data/repositories/community_post_repository.dart';
import '../controllers/community_controller.dart';

/// `/community` 라우트로 직접 진입할 때(딥링크·푸시)만 실행되는 바인딩.
///
/// 바텀 네비게이션으로 들어오는 일반 경로에서는 `AppBinding` 이 같은 의존성을
/// 먼저 등록한다 — `AppView` 의 `IndexedStack` 이 전 탭을 동시에 마운트하므로
/// 이 바인딩은 `/app` 진입 시 실행되지 않는다.
class CommunityBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CommunityPostRepository>(
      () => CommunityPostRepository(),
      fenix: true,
    );
    // 글쓰기 FAB의 작성 게이트가 사용한다.
    Get.lazyPut<CommunityModerationRepository>(
      () => CommunityModerationRepository(),
      fenix: true,
    );
    Get.lazyPut<CommunityController>(() => CommunityController());
  }
}
