import 'package:get/get.dart';

import '../../../data/repositories/profile_repository.dart';
import '../controllers/profile_edit_controller.dart';

class ProfileEditBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileRepository>(() => ProfileRepository(), fenix: true);
    Get.lazyPut<ProfileEditController>(() => ProfileEditController());
  }
}
