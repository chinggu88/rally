import 'package:get/get.dart';

import '../../../data/repositories/chat_message_repository.dart';
import '../../../data/repositories/community_moderation_repository.dart';
import '../controllers/live_match_chat_controller.dart';

class LiveMatchChatBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatMessageRepository>(
      () => ChatMessageRepository(),
      fenix: true,
    );
    // 채팅 신고·차단이 커뮤니티와 같은 레포지토리를 쓴다. AppBinding 에도
    // 등록돼 있지만, 딥링크로 채팅방에 바로 들어오는 경로를 위해 여기서도
    // 보장한다(fenix 라 중복 등록이 문제되지 않는다).
    Get.lazyPut<CommunityModerationRepository>(
      () => CommunityModerationRepository(),
      fenix: true,
    );
    Get.lazyPut<LiveMatchChatController>(() => LiveMatchChatController());
  }
}
