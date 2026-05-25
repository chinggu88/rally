import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignUpController extends GetxController {
  static SignUpController get to => Get.find();

  // Form controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();

  // Reactive state
  final _isLoading = false.obs;
  final _isEmailValid = false.obs;
  final _isVerificationSent = false.obs;
  final _remainingSeconds = 0.obs;

  Timer? _verificationTimer;

  bool get isLoading => _isLoading.value;
  set isLoading(bool value) => _isLoading.value = value;

  bool get isEmailValid => _isEmailValid.value;
  bool get isVerificationSent => _isVerificationSent.value;
  int get remainingSeconds => _remainingSeconds.value;

  /// "mm:ss" 형식의 잔여 시간
  String get formattedRemaining {
    final minutes = (_remainingSeconds.value ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds.value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static const int _verificationDurationSec = 180; // 3분

  @override
  void onInit() {
    super.onInit();
    emailController.addListener(_validateEmail);
  }

  @override
  void onClose() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
    emailController.removeListener(_validateEmail);
    emailController.dispose();
    codeController.dispose();
    super.onClose();
  }

  void _validateEmail() {
    final text = emailController.text.trim();
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    _isEmailValid.value = regex.hasMatch(text);
  }

  /// 인증 메일/링크 발송 요청 — API 연동 전 placeholder
  Future<void> requestVerification() async {
    if (isLoading) return;
    if (!isEmailValid) {
      Get.snackbar(
        '이메일 확인',
        '올바른 이메일 형식을 입력해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading = true;
      // TODO: 인증 메일 발송 API 연동 (별도 태스크)
      // await _authRepository.requestEmailVerification(
      //   email: emailController.text.trim(),
      // );
      await Future<void>.delayed(const Duration(milliseconds: 400));

      _isVerificationSent.value = true;
      _startVerificationTimer();

      Get.snackbar(
        '메일 발송',
        '입력하신 이메일로 인증 링크를 보냈습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading = false;
    }
  }

  /// 인증 코드 검증 — API 연동 전 placeholder
  Future<void> verifyCode() async {
    if (isLoading) return;
    if (codeController.text.trim().isEmpty) {
      Get.snackbar(
        '인증번호 확인',
        '인증번호를 입력해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading = true;
      // TODO: 인증 코드 검증 API 연동 (별도 태스크)
      await Future<void>.delayed(const Duration(milliseconds: 400));

      Get.snackbar(
        '안내',
        '인증 검증 API는 추후 연동 예정입니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading = false;
    }
  }

  /// 재발송
  Future<void> resendVerification() async {
    _verificationTimer?.cancel();
    _remainingSeconds.value = 0;
    _isVerificationSent.value = false;
    await requestVerification();
  }

  /// 로그인 화면으로 복귀
  void goToLogin() {
    Get.back();
  }

  void _startVerificationTimer() {
    _verificationTimer?.cancel();
    _remainingSeconds.value = _verificationDurationSec;
    _verificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds.value <= 0) {
        timer.cancel();
        return;
      }
      _remainingSeconds.value -= 1;
    });
  }
}
