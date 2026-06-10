import 'package:get/get.dart';

import '../../../data/repositories/live_match_repository.dart';
import '../../../data/repositories/news_card_repository.dart';
import '../../../data/repositories/today_match_repository.dart';
import '../../../data/repositories/tournament_repository.dart';
import '../controllers/news_controller.dart';

class NewsBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LiveMatchRepository>(() => LiveMatchRepository(), fenix: true);
    Get.lazyPut<TodayMatchRepository>(
      () => TodayMatchRepository(),
      fenix: true,
    );
    Get.lazyPut<NewsCardRepository>(() => NewsCardRepository(), fenix: true);
    Get.lazyPut<TournamentRepository>(() => TournamentRepository(), fenix: true);
    Get.lazyPut(() => NewsController());
  }
}
