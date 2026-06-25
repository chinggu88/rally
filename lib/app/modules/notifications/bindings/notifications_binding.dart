import 'package:get/get.dart';

import '../../../data/repositories/notification_repository.dart';
import '../controllers/notifications_controller.dart';

class NotificationsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotificationRepository>(
      () => NotificationRepository(),
      fenix: true,
    );
    Get.lazyPut<NotificationsController>(() => NotificationsController());
  }
}
