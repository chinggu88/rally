import 'package:get/get.dart';

import '../../../data/repositories/favorite_player_repository.dart';
import '../controllers/favorite_players_controller.dart';

class FavoritePlayersBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FavoritePlayerRepository>(
      () => FavoritePlayerRepository(),
      fenix: true,
    );
    Get.lazyPut<FavoritePlayersController>(() => FavoritePlayersController());
  }
}
