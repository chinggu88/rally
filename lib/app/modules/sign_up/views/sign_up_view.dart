import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../controllers/sign_up_controller.dart';

/// 회원가입 — Email + Password + 인증 메일 (Supabase Email Confirm)
class SignUpView extends GetView<SignUpController> {
  const SignUpView({super.key});

  // --- Design tokens ---
  static const Color _bg = AppColors.bg;
  static const Color _accent = AppColors.accentLime;
  static const Color _subtle = AppColors.subtleText;
  static const Color _hint = Color(0xFF5C5F5D);
  static const Color _divider = AppColors.divider;
  static const Color _cardBg = Color(0xFF14181A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20.sp),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Obx(
          () => controller.isEmailSent
              ? _buildEmailSentBody()
              : _buildFormBody(),
        ),
      ),
    );
  }

  // ----- Form -----
  Widget _buildFormBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroImage(),
          SizedBox(height: 24.h),
          _buildHeader(),
          SizedBox(height: 32.h),
          _buildEmailField(),
          SizedBox(height: 16.h),
          _buildPasswordField(),
          SizedBox(height: 16.h),
          _buildInfoBox(),
          SizedBox(height: 24.h),
          _buildSubmitButton(),
          SizedBox(height: 20.h),
          _buildDivider(),
          SizedBox(height: 16.h),
          _buildSocialButton(
            label: 'Apple로 가입하기',
            iconWidget:
                Icon(Icons.apple, size: 22.sp, color: Colors.black),
            bg: Colors.white,
            fg: Colors.black,
            onTap: controller.signUpWithApple,
          ),
          SizedBox(height: 12.h),
          _buildSocialButton(
            label: 'Google로 가입하기',
            iconWidget: Image.asset(
              'assets/images/google_logo.png',
              width: 20.sp,
              height: 20.sp,
            ),
            bg: Colors.white,
            fg: Colors.black,
            onTap: controller.signUpWithGoogle,
          ),
          SizedBox(height: 12.h),
          _buildSocialButton(
            label: '카카오로 가입하기',
            iconWidget: Icon(
              Icons.chat_bubble,
              size: 20.sp,
              color: Colors.black,
            ),
            bg: const Color(0xFFFEE500),
            fg: Colors.black,
            onTap: controller.signUpWithKakao,
          ),
          SizedBox(height: 20.h),
          _buildLoginRow(),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Container(
      height: 160.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [AppColors.gradientStartAlt, AppColors.bg],
        ),
        border: Border.all(color: _divider),
      ),
      child: Center(
        child: Icon(
          Icons.sports_tennis,
          color: _accent,
          size: 56.sp,
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
            fontSize: 26.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '회원가입',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
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
        hintText: '이메일을 입력하세요',
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
        onSubmitted: (_) => controller.signUp(),
        style: TextStyle(color: Colors.white, fontSize: 15.sp),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: '비밀번호 (6자 이상)',
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

  Widget _buildInfoBox() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: _accent, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              '회원가입 후 입력하신 이메일로 인증 메일을 보내드립니다. 메일의 링크를 눌러 인증을 완료하면 자동 로그인됩니다.',
              style: TextStyle(
                color: _subtle,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Obx(
      () => SizedBox(
        height: 52.h,
        child: ElevatedButton(
          onPressed: controller.isLoading ? null : controller.signUp,
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
                  '회원가입',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
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
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '이미 계정이 있으신가요? ',
          style: TextStyle(color: _subtle, fontSize: 13.sp),
        ),
        GestureDetector(
          onTap: controller.goToLogin,
          child: Text(
            '로그인',
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

  // ----- Email Sent -----
  Widget _buildEmailSentBody() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 32.h),
          Icon(Icons.mark_email_read_outlined, color: _accent, size: 64.sp),
          SizedBox(height: 24.h),
          Text(
            '인증 메일을 보냈습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            '${controller.emailController.text.trim()}로\n인증 메일을 발송했습니다.\n메일함을 확인해 인증을 완료해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subtle,
              fontSize: 13.sp,
              height: 1.6,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 52.h,
            child: ElevatedButton(
              onPressed: () => Get.offAllNamed(Routes.LOGIN),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r),
                ),
              ),
              child: Text(
                '로그인 화면으로 이동',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
