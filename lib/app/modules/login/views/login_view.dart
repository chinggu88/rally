import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/login_controller.dart';

/// 로그인 — Stitch: 로그인 (Kinetic Court)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : a7cf71e767ad4610a93373028a9c3ab0
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  // --- Design tokens ---
  static const Color _bg = AppColors.bg;
  static const Color _accent = AppColors.accentLime;
  static const Color _subtle = AppColors.subtleText;
  static const Color _hint = Color(0xFF5C5F5D);
  static const Color _divider = AppColors.divider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 48.h, 24.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              SizedBox(height: 64.h),
              _buildEmailField(),
              SizedBox(height: 24.h),
              _buildPasswordField(),
              SizedBox(height: 48.h),
              _buildLoginButton(),
              SizedBox(height: 32.h),
              _buildDivider(),
              SizedBox(height: 24.h),
              _buildSocialButton(
                label: 'Apple로 계속하기',
                iconWidget:
                    Icon(Icons.apple, size: 22.sp, color: Colors.black),
                bg: Colors.white,
                fg: Colors.black,
                onTap: controller.signInWithApple,
              ),
              SizedBox(height: 12.h),
              _buildSocialButton(
                label: 'Google로 계속하기',
                iconWidget: Image.asset(
                  'assets/images/google_logo.png',
                  width: 20.sp,
                  height: 20.sp,
                ),
                bg: Colors.white,
                fg: Colors.black,
                onTap: controller.signInWithGoogle,
              ),
              SizedBox(height: 24.h),
              _buildSignUpRow(),
              SizedBox(height: 12.h),
              _buildForgotPassword(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: _divider, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            '또는',
            style: TextStyle(color: _subtle, fontSize: 12.sp),
          ),
        ),
        const Expanded(child: Divider(color: _divider, height: 1)),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    required Widget iconWidget,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Obx(
      () => SizedBox(
        height: 52.h,
        child: ElevatedButton(
          onPressed: controller.isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            disabledBackgroundColor: bg.withValues(alpha: 0.5),
            foregroundColor: fg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.r),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              SizedBox(width: 10.w),
              Text(
                label,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rally',
          style: TextStyle(
            color: _accent,
            fontSize: 32.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '프리미엄 배드민턴 커뮤니티',
          style: TextStyle(color: _subtle, fontSize: 13.sp),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: controller.emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: Colors.white, fontSize: 15.sp),
      cursorColor: _accent,
      decoration: InputDecoration(
        hintText: '이메일',
        hintStyle: TextStyle(color: _hint, fontSize: 15.sp),
        prefixIcon: Icon(Icons.mail_outline, color: _hint, size: 20.sp),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _divider),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _accent, width: 1.4),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14.h),
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
        style: TextStyle(color: Colors.white, fontSize: 15.sp),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: '비밀번호',
          hintStyle: TextStyle(color: _hint, fontSize: 15.sp),
          prefixIcon: Icon(Icons.lock_outline, color: _hint, size: 20.sp),
          suffixIcon: IconButton(
            onPressed: controller.togglePasswordObscured,
            icon: Icon(
              controller.isPasswordObscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _hint,
              size: 20.sp,
            ),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _accent, width: 1.4),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Obx(
      () => SizedBox(
        height: 52.h,
        child: ElevatedButton(
          onPressed: controller.isLoading ? null : controller.login,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            disabledBackgroundColor: _accent.withValues(alpha: 0.5),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.r),
            ),
          ),
          child: controller.isLoading
              ? SizedBox(
                  width: 22.w,
                  height: 22.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.black),
                  ),
                )
              : Text(
                  '로그인',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '계정이 없으신가요? ',
          style: TextStyle(color: _subtle, fontSize: 13.sp),
        ),
        GestureDetector(
          onTap: controller.goToSignUp,
          child: Text(
            '회원가입',
            style: TextStyle(
              color: _accent,
              fontSize: 13.sp,
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
        child: Text(
          '비밀번호를 잊으셨나요?',
          style: TextStyle(color: _subtle, fontSize: 13.sp),
        ),
      ),
    );
  }
}
