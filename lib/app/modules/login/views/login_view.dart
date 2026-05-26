import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/login_controller.dart';

/// 로그인 — Stitch: 로그인 (Kinetic Court)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : a7cf71e767ad4610a93373028a9c3ab0
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  // --- Design tokens ---
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _accent = Color(0xFFD7FF00);
  static const Color _subtle = Color(0xFF9CA3A1);
  static const Color _hint = Color(0xFF5C5F5D);
  static const Color _divider = Color(0xFF1F2421);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 64),
              _buildEmailField(),
              const SizedBox(height: 24),
              _buildPasswordField(),
              const SizedBox(height: 48),
              _buildLoginButton(),
              const SizedBox(height: 16),
              _buildSignUpRow(),
              const SizedBox(height: 12),
              _buildForgotPassword(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Kinetic Court',
          style: TextStyle(
            color: _accent,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '프리미엄 배드민턴 커뮤니티',
          style: TextStyle(color: _subtle, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: controller.emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: _accent,
      decoration: InputDecoration(
        hintText: '이메일',
        hintStyle: const TextStyle(color: _hint, fontSize: 15),
        prefixIcon: const Icon(Icons.mail_outline, color: _hint, size: 20),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _divider),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _accent, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Obx(
      () => TextField(
        controller: controller.passwordController,
        obscureText: controller.isPasswordObscured,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => controller.login(),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: '비밀번호',
          hintStyle: const TextStyle(color: _hint, fontSize: 15),
          prefixIcon: const Icon(Icons.lock_outline, color: _hint, size: 20),
          suffixIcon: IconButton(
            onPressed: controller.togglePasswordObscured,
            icon: Icon(
              controller.isPasswordObscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _hint,
              size: 20,
            ),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _accent, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Obx(
      () => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: controller.isLoading ? null : controller.login,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            disabledBackgroundColor: _accent.withValues(alpha: 0.5),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: controller.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.black),
                  ),
                )
              : const Text(
                  '로그인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '계정이 없으신가요? ',
          style: TextStyle(color: _subtle, fontSize: 13),
        ),
        GestureDetector(
          onTap: controller.goToSignUp,
          child: const Text(
            '회원가입',
            style: TextStyle(
              color: _accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Center(
      child: GestureDetector(
        onTap: controller.goToForgotPassword,
        child: const Text(
          '비밀번호를 잊으셨나요?',
          style: TextStyle(color: _subtle, fontSize: 13),
        ),
      ),
    );
  }
}
