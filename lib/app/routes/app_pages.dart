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
import '../modules/favorite_players/bindings/favorite_players_binding.dart';
import '../modules/favorite_players/views/favorite_players_view.dart';
import '../modules/my_info/bindings/my_info_binding.dart';
import '../modules/my_info/views/my_info_view.dart';
import '../modules/profile_edit/bindings/profile_edit_binding.dart';
import '../modules/profile_edit/views/profile_edit_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/notifications/bindings/notifications_binding.dart';
import '../modules/notifications/views/notifications_view.dart';
import '../modules/live_match_chat/bindings/live_match_chat_binding.dart';
import '../modules/live_match_chat/views/live_match_chat_view.dart';
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
      name: Routes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
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
      name: Routes.PROFILE_EDIT,
      page: () => const ProfileEditView(),
      binding: ProfileEditBinding(),
    ),
    GetPage(
      name: Routes.FAVORITE_PLAYERS,
      page: () => const FavoritePlayersView(),
      binding: FavoritePlayersBinding(),
    ),
    GetPage(
      name: Routes.NOTIFICATIONS,
      page: () => const NotificationsView(),
      binding: NotificationsBinding(),
    ),
    GetPage(
      name: Routes.LIVE_MATCH_CHAT,
      page: () => const LiveMatchChatView(),
      binding: LiveMatchChatBinding(),
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
