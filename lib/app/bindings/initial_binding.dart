import 'package:get/get.dart';

import '../../services/favorite_match_service.dart';
import '../../services/live_activity_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../data/repositories/auth_repository.dart';

class InitialBinding implements Bindings {
  @override
  void dependencies() {
    // 전역 GetxService 등록 (Get.find()로 접근 가능)
    Get.put(SupabaseService(), permanent: true);
    Get.put(AuthRepository(), permanent: true);
    Get.put(NotificationService(), permanent: true);
    // Live Activity는 FavoriteMatchService가 참조하므로 먼저 등록한다.
    Get.put(LiveActivityService(), permanent: true);
    // 관심 경기 + 홈스크린 위젯 — 홈 탭 생명주기와 무관하게 살아있어야 한다.
    Get.put(FavoriteMatchService(), permanent: true);
  }
}
