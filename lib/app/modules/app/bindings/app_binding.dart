import 'package:get/get.dart';

import '../../../data/repositories/community_moderation_repository.dart';
import '../../../data/repositories/community_post_repository.dart';
import '../../../data/repositories/favorite_player_repository.dart';
import '../../../data/repositories/live_match_repository.dart';
import '../../../data/repositories/news_card_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/today_match_repository.dart';
import '../../../data/repositories/tournament_repository.dart';
import '../../community/controllers/community_controller.dart';
import '../../match/controllers/match_controller.dart';
import '../../my_info/controllers/my_info_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/app_controller.dart';

class AppBinding implements Bindings {
  @override
  void dependencies() {
    Get.put(AppController(), permanent: true);
    // 홈(HomeController)이 사용하는 라이브 매치 레포지토리.
    // HomeBinding에서도 fenix로 등록하지만, 바텀 네비게이션 진입이
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
    // 커뮤니티 탭(CommunityController)이 사용하는 게시글 레포지토리.
    // CommunityBinding에서도 fenix로 등록하지만, AppView의 IndexedStack이
    // 5개 탭을 동시에 마운트해 CommunityView가 /app 진입 즉시 build되므로
    // (CommunityBinding은 딥링크로 /community에 직접 들어올 때만 실행된다)
    // 여기서 먼저 보장하지 않으면 앱 진입 시점에 not found 예외가 난다.
    Get.lazyPut<CommunityPostRepository>(
      () => CommunityPostRepository(),
      fenix: true,
    );
    // 작성 게이트(CommunityOnboardingController.ensureCanWrite)가 목록 FAB과
    // 상세 수정 메뉴에서 호출되는데, 두 경로 모두 CommunityComposeBinding보다
    // 먼저 실행된다. 여기서 등록하지 않으면 FAB을 누르는 순간 not found 다.
    Get.lazyPut<CommunityModerationRepository>(
      () => CommunityModerationRepository(),
      fenix: true,
    );
    Get.lazyPut(() => HomeController());
    Get.lazyPut(() => MatchController());
    Get.lazyPut(() => PlayerController());
    Get.lazyPut(() => CommunityController());
    Get.lazyPut(() => MyInfoController());
  }
}
