import 'package:get/get.dart';

import '../controllers/my_info_controller.dart';

class MyInfoBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MyInfoController());
  }
}
