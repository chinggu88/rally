import 'package:get/get.dart';

import '../../../data/repositories/community_comment_repository.dart';
import '../../../data/repositories/community_moderation_repository.dart';
import '../../../data/repositories/community_post_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../controllers/community_post_detail_controller.dart';

/// `/community/post` 라우트 바인딩.
///
/// 커뮤니티 탭을 거쳐 들어오면 `AppBinding` 이 이미 [CommunityPostRepository] 를
/// 등록해 뒀지만, 푸시·딥링크로 상세에 바로 진입할 수도 있으므로 여기서도
/// 등록한다 (`fenix: true` 라 재등록해도 기존 인스턴스를 덮지 않는다).
class CommunityPostDetailBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CommunityPostRepository>(
      () => CommunityPostRepository(),
      fenix: true,
    );
    // 댓글은 상세 화면에서만 쓰므로 AppBinding 이 아니라 여기서만 등록한다.
    Get.lazyPut<CommunityCommentRepository>(
      () => CommunityCommentRepository(),
      fenix: true,
    );
    // 본인 글 수정 메뉴의 작성 게이트와 댓글 금칙어 사전이 사용한다.
    Get.lazyPut<CommunityModerationRepository>(
      () => CommunityModerationRepository(),
      fenix: true,
    );
    Get.lazyPut<ProfileRepository>(() => ProfileRepository(), fenix: true);
    Get.lazyPut<CommunityPostDetailController>(
      () => CommunityPostDetailController(),
    );
  }
}
