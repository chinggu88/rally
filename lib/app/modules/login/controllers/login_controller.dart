import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  static LoginController get to => Get.find();

  // Form controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Reactive state
  final _isLoading = false.obs;
  final _isEmailValid = false.obs;
  final _isPasswordValid = false.obs;
  final _isPasswordObscured = true.obs;

  bool get isLoading => _isLoading.value;
  set isLoading(bool value) => _isLoading.value = value;

  bool get isEmailValid => _isEmailValid.value;
  bool get isPasswordValid => _isPasswordValid.value;
  bool get isPasswordObscured => _isPasswordObscured.value;

  bool get canSubmit => isEmailValid && isPasswordValid && !isLoading;

  @override
  void onInit() {
    super.onInit();
    emailController.addListener(_validateEmail);
    passwordController.addListener(_validatePassword);
  }

  @override
  void onClose() {
    emailController.removeListener(_validateEmail);
    passwordController.removeListener(_validatePassword);
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void _validateEmail() {
    final text = emailController.text.trim();
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    _isEmailValid.value = regex.hasMatch(text);
  }

  void _validatePassword() {
    _isPasswordValid.value = passwordController.text.length >= 6;
  }

  void togglePasswordObscured() {
    _isPasswordObscured.value = !_isPasswordObscured.value;
  }

  /// 로그인 화면 → 회원가입 이메일 인증 화면으로 이동
  void goToSignUp() {
    if (Get.currentRoute == Routes.SIGN_UP) return; // 중복 push 방지
    Get.toNamed(Routes.SIGN_UP);
  }

  /// 로그인 실행 — API 연동 전 placeholder
  Future<void> login() async {
    if (isLoading) return;
    if (!canSubmit) {
      Get.snackbar(
        '입력 확인',
        '이메일과 비밀번호를 정확히 입력해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading = true;
      // TODO: 인증 API 연동 (별도 태스크)
      // final result = await _authRepository.login(
      //   email: emailController.text.trim(),
      //   password: passwordController.text,
      // );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      Get.snackbar(
        '안내',
        '로그인 API는 추후 연동 예정입니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading = false;
    }
  }

  /// 비밀번호 찾기 — placeholder
  void goToForgotPassword() {
    // TODO: 비밀번호 찾기 화면 라우트 추가 시 연결
  }
}
