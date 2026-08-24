import 'package:get/get.dart';

import '../../../data/repositories/community_moderation_repository.dart';
import '../../../data/repositories/community_post_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../controllers/community_compose_controller.dart';

/// `/community/compose` 라우트 바인딩 (작성 · 수정 겸용).
///
/// 레포지토리들은 `AppBinding` 이 이미 등록해 두지만, 푸시·딥링크로 작성
/// 화면에 바로 들어올 수 있으므로 여기서도 보장한다 (`fenix: true` 라
/// 재등록해도 기존 인스턴스를 덮지 않는다).
///
/// [ProfileRepository] 는 이 화면이 직접 쓰지는 않지만, 진입 게이트
/// (`CommunityOnboardingController.ensureCanWrite`)와 온보딩 시트가 닉네임
/// 저장에 쓴다. 게이트는 이 바인딩보다 먼저 도는 경로
/// (목록 FAB · 상세 수정)에서 호출되므로 `AppBinding` 등록이 본선이고
/// 여기 등록은 딥링크 대비다.
class CommunityComposeBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CommunityPostRepository>(
      () => CommunityPostRepository(),
      fenix: true,
    );
    Get.lazyPut<CommunityModerationRepository>(
      () => CommunityModerationRepository(),
      fenix: true,
    );
    Get.lazyPut<ProfileRepository>(() => ProfileRepository(), fenix: true);
    Get.lazyPut<CommunityComposeController>(() => CommunityComposeController());
  }
}
