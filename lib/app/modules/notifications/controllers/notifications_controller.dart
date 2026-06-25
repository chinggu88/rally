import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/notification_response.dart';
import '../../../data/repositories/notification_repository.dart';

/// 알림 목록 화면 컨트롤러.
class NotificationsController extends GetxController {
  final NotificationRepository _repository = Get.find<NotificationRepository>();

  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final _items = <NotificationResponse>[].obs;
  List<NotificationResponse> get items => _items;

  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      _isLoading.value = true;
      _errorMessage.value = null;
      final list = await _repository.listNotifications();
      _items.assignAll(list);
    } catch (e) {
      log('NotificationsController.load error: $e');
      _errorMessage.value = '알림을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      _isLoading.value = false;
    }
  }
}
