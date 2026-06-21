import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/auth_repository.dart';

class SignUpController extends GetxController {
  static SignUpController get to => Get.find();

  final AuthRepository _authRepository = Get.find<AuthRepository>();

  // Form controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Reactive state
  final _isLoading = false.obs;
  final _isEmailValid = false.obs;
  final _isPasswordValid = false.obs;
  final _isPasswordObscured = true.obs;
  final _isEmailSent = false.obs;

  bool get isLoading => _isLoading.value;
  set isLoading(bool value) => _isLoading.value = value;

  bool get isEmailValid => _isEmailValid.value;
  bool get isPasswordValid => _isPasswordValid.value;
  bool get isPasswordObscured => _isPasswordObscured.value;
  bool get isEmailSent => _isEmailSent.value;

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

  /// 회원가입 실행 — Supabase signUp 호출.
  /// Email Confirm이 켜져 있으면 session이 null로 반환되고, 안내 화면으로 전환한다.
  /// Confirm이 꺼져 있으면 session이 발급되어 LoginController의 authStateChanges 구독자가 라우팅한다.
  Future<void> signUp() async {
    if (isLoading || !canSubmit) return;
    try {
      isLoading = true;
      final res = await _authRepository.signUpWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (res.session == null) {
        _isEmailSent.value = true;
      }
    } on AuthException catch (e) {
      Get.snackbar(
        '회원가입 실패',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '오류',
        '회원가입 중 문제가 발생했습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading = false;
    }
  }

  Future<void> signUpWithGoogle() =>
      _runSocial(_authRepository.signInWithGoogle, 'Google');
  Future<void> signUpWithApple() =>
      _runSocial(_authRepository.signInWithApple, 'Apple');
  Future<void> signUpWithKakao() =>
      _runSocial(_authRepository.signInWithKakao, 'Kakao');

  Future<void> _runSocial(
    Future<dynamic> Function() fn,
    String providerLabel,
  ) async {
    if (isLoading) return;
    try {
      isLoading = true;
      await fn();
      // OAuth: 외부 브라우저로 이동 → 콜백 시 LoginController의 authStateChanges가 라우팅 처리
    } on AuthException catch (e) {
      Get.snackbar(
        '$providerLabel 회원가입 실패',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '$providerLabel 회원가입 실패',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading = false;
    }
  }

  /// 로그인 화면으로 복귀
  void goToLogin() {
    Get.back();
  }
}
