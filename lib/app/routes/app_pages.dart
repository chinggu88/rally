import 'package:get/get.dart';

import '../modules/app/bindings/app_binding.dart';
import '../modules/app/views/app_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/match/bindings/match_binding.dart';
import '../modules/match/bindings/tournament_detail_binding.dart';
import '../modules/match/bindings/tournament_participants_binding.dart';
import '../modules/match/views/match_view.dart';
import '../modules/match/views/tournament_detail_view.dart';
import '../modules/match/views/tournament_participants_view.dart';
import '../modules/my_info/bindings/my_info_binding.dart';
import '../modules/my_info/views/my_info_view.dart';
import '../modules/news/bindings/news_binding.dart';
import '../modules/news/views/news_view.dart';
import '../modules/player/bindings/player_binding.dart';
import '../modules/player/bindings/player_detail_binding.dart';
import '../modules/player/views/player_detail_view.dart';
import '../modules/player/views/player_view.dart';
import '../modules/sign_up/bindings/sign_up_binding.dart';
import '../modules/sign_up/views/sign_up_view.dart';
import 'app_routes.dart';

abstract class AppPages {
  AppPages._();

  static final List<GetPage> routes = [
    GetPage(
      name: Routes.APP,
      page: () => const AppView(),
      binding: AppBinding(),
    ),
    GetPage(
      name: Routes.NEWS,
      page: () => const NewsView(),
      binding: NewsBinding(),
    ),
    GetPage(
      name: Routes.MATCH,
      page: () => const MatchView(),
      binding: MatchBinding(),
    ),
    GetPage(
      name: Routes.MATCH_DETAIL,
      page: () => const TournamentDetailView(),
      binding: TournamentDetailBinding(),
    ),
    GetPage(
      name: Routes.MATCH_PARTICIPANTS,
      page: () => const TournamentParticipantsView(),
      binding: TournamentParticipantsBinding(),
    ),
    GetPage(
      name: Routes.PLAYER,
      page: () => const PlayerView(),
      binding: PlayerBinding(),
    ),
    GetPage(
      name: Routes.PLAYER_DETAIL,
      page: () => const PlayerDetailView(),
      binding: PlayerDetailBinding(),
    ),
    GetPage(
      name: Routes.MY_INFO,
      page: () => const MyInfoView(),
      binding: MyInfoBinding(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.SIGN_UP,
      page: () => const SignUpView(),
      binding: SignUpBinding(),
    ),
  ];
}
