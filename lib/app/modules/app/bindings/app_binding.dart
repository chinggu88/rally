import 'package:get/get.dart';

import '../../../data/repositories/favorite_player_repository.dart';
import '../../../data/repositories/live_match_repository.dart';
import '../../../data/repositories/news_card_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/today_match_repository.dart';
import '../../../data/repositories/tournament_repository.dart';
import '../../match/controllers/match_controller.dart';
import '../../my_info/controllers/my_info_controller.dart';
import '../../news/controllers/news_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/app_controller.dart';

class AppBinding implements Bindings {
  @override
  void dependencies() {
    Get.put(AppController(), permanent: true);
    // 홈(NewsController)이 사용하는 라이브 매치 레포지토리.
    // NewsBinding에서도 fenix로 등록하지만, 바텀 네비게이션 진입이
    // 항상 AppBinding을 거치므로 여기서 먼저 보장한다.
    Get.lazyPut<LiveMatchRepository>(() => LiveMatchRepository(), fenix: true);
    Get.lazyPut<TodayMatchRepository>(
      () => TodayMatchRepository(),
      fenix: true,
    );
    Get.lazyPut<NewsCardRepository>(() => NewsCardRepository(), fenix: true);
    Get.lazyPut<TournamentRepository>(() => TournamentRepository(), fenix: true);
    // 마이페이지(프로필/좋아하는 선수)에서 사용하는 유저 스코프 레포지토리.
    Get.lazyPut<ProfileRepository>(() => ProfileRepository(), fenix: true);
    Get.lazyPut<FavoritePlayerRepository>(
      () => FavoritePlayerRepository(),
      fenix: true,
    );
    Get.lazyPut(() => NewsController());
    Get.lazyPut(() => MatchController());
    Get.lazyPut(() => PlayerController());
    Get.lazyPut(() => MyInfoController());
  }
}
