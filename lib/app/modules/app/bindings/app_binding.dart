import 'package:get/get.dart';

import '../../match/controllers/match_controller.dart';
import '../../my_info/controllers/my_info_controller.dart';
import '../../news/controllers/news_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/app_controller.dart';

class AppBinding implements Bindings {
  @override
  void dependencies() {
    Get.put(AppController(), permanent: true);
    Get.lazyPut(() => NewsController());
    Get.lazyPut(() => MatchController());
    Get.lazyPut(() => PlayerController());
    Get.lazyPut(() => MyInfoController());
  }
}
