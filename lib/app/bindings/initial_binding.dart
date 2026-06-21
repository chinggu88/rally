import 'package:get/get.dart';

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
  }
}
