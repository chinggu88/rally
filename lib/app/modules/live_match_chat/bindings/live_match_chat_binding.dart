import 'package:get/get.dart';

import '../../../data/repositories/chat_message_repository.dart';
import '../controllers/live_match_chat_controller.dart';

class LiveMatchChatBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChatMessageRepository>(
      () => ChatMessageRepository(),
      fenix: true,
    );
    Get.lazyPut<LiveMatchChatController>(() => LiveMatchChatController());
  }
}
