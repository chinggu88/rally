import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

class MyInfoController extends GetxController {
  static MyInfoController get to => Get.find();

  final AuthRepository _authRepository = Get.find<AuthRepository>();
  StreamSubscription<AuthState>? _authSub;

  final _isLoggedIn = false.obs;
  bool get isLoggedIn => _isLoggedIn.value;

  String? get email => _authRepository.currentUser?.email;

  @override
  void onInit() {
    super.onInit();
    _isLoggedIn.value = _authRepository.currentSession != null;
    _authSub = _authRepository.authStateChanges.listen((state) {
      _isLoggedIn.value = state.session != null;
    });
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
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

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
      Get.snackbar(
        '로그아웃',
        '안녕히 가세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on AuthException catch (e) {
      Get.snackbar(
        '로그아웃 실패',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
