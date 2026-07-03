import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  static LoginController get to => Get.find();

  final AuthRepository _authRepository = Get.find<AuthRepository>();
  // StreamSubscription<AuthState>? _authSub;

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

  /// 이메일 로그인 실행
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
      await _authRepository.signInWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      // 성공 시 _authSub 콜백이 Get.offAllNamed(Routes.APP) 호출
    } on AuthException catch (e) {
      Get.snackbar('로그인 실패', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar(
        '오류',
        '로그인 중 문제가 발생했습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading = false;
    }
  }

  Future<void> signInWithGoogle() =>
      _runSocial(_authRepository.signInWithGoogle);
  Future<void> signInWithApple() => _runSocial(_authRepository.signInWithApple);

  /// Apple 네이티브 로그인 (iOS 시스템 시트, 외부 브라우저 없음).
  Future<void> signInWithAppleNative() =>
      _runSocial(_authRepository.signInWithAppleNative);

  Future<void> _runSocial(Future<dynamic> Function() fn) async {
    if (isLoading) return;
    try {
      isLoading = true;
      await fn();
      // OAuth: 인앱 브라우저(SFSafariViewController) → 콜백 시 authStateChanges → SIGNED_IN
    } on AuthException catch (e) {
      Get.snackbar('로그인 실패', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('로그인 실패', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading = false;
    }
  }

  /// 비밀번호 찾기 — placeholder
  void goToForgotPassword() {
    // TODO: 비밀번호 찾기 화면 라우트 추가 시 연결
  }
}
