import 'package:get/get.dart';

import '../../../data/repositories/live_match_repository.dart';
import '../controllers/news_controller.dart';

class NewsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LiveMatchRepository>(() => LiveMatchRepository(), fenix: true);
    Get.lazyPut(() => NewsController());
  }
}
