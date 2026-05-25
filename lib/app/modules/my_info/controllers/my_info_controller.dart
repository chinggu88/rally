import 'package:get/get.dart';

import '../../../routes/app_routes.dart';

class MyInfoController extends GetxController {
  static MyInfoController get to => Get.find();

  // 로그인 상태 (현재는 항상 false — 추후 GetStorage 연동 예정)
  final _isLoggedIn = false.obs;
  bool get isLoggedIn => _isLoggedIn.value;

  @override
  void onInit() {
    super.onInit();
    // TODO: GetStorage에서 토큰 조회하여 _isLoggedIn 초기화 (별도 태스크)
    // 추후 isLoggedIn 값에 따라 비로그인 진입 화면 / 로그인 후 프로필 화면 분기
  }

  /// 비로그인 안내 화면 → 로그인 화면으로 이동
  void goToLogin() {
    if (Get.currentRoute == Routes.LOGIN) return; // 중복 push 방지
    Get.toNamed(Routes.LOGIN);
  }

  /// 비로그인 안내 화면 → 회원가입(이메일 인증) 화면으로 이동
  void goToSignUp() {
    if (Get.currentRoute == Routes.SIGN_UP) return;
    Get.toNamed(Routes.SIGN_UP);
  }
}
