import 'package:get/get.dart';

import '../controllers/match_controller.dart';

class MatchBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MatchController());
  }
}
