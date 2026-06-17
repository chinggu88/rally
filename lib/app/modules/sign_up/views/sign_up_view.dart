import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/sign_up_controller.dart';

/// 회원가입 - 이메일 인증 — Stitch: 회원가입 - 이메일 인증 (Kinetic Court)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : 3616350c62da4e95906ab4d458eb7ebc
class SignUpView extends GetView<SignUpController> {
  const SignUpView({super.key});

  // --- Design tokens ---
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _accent = Color(0xFFD7FF00);
  static const Color _subtle = Color(0xFF9CA3A1);
  static const Color _hint = Color(0xFF5C5F5D);
  static const Color _divider = Color(0xFF1F2421);
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
        child: SingleChildScrollView(
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
              _buildVerificationInfoBox(),
              SizedBox(height: 20.h),
              _buildVerificationSection(),
              SizedBox(height: 24.h),
              _buildSubmitButton(),
              SizedBox(height: 20.h),
              _buildLoginRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    // Stitch 디자인의 상단 배드민턴 선수 실루엣 영역 (이미지 자산 없음 — 그라데이션으로 대체)
    return Container(
      height: 160.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF202521), Color(0xFF0A0A0A)],
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
          '회원가입 - 이메일 인증',
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
      textInputAction: TextInputAction.done,
      style: TextStyle(color: Colors.white, fontSize: 15.sp),
      cursorColor: _accent,
      decoration: InputDecoration(
        hintText: '이메일을 입력하세요',
        hintStyle: TextStyle(color: _hint, fontSize: 15.sp),
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

  Widget _buildVerificationInfoBox() {
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
              '보안 인증 링크를 이메일로 보내드립니다. 비밀번호 없이 첫 단계를 시작할 수 있습니다.',
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

  Widget _buildVerificationSection() {
    return Obx(() {
      if (!controller.isVerificationSent) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller.codeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: Colors.white, fontSize: 15.sp),
            cursorColor: _accent,
            decoration: InputDecoration(
              hintText: '인증번호 입력',
              hintStyle: TextStyle(color: _hint, fontSize: 15.sp),
              suffixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    controller.formattedRemaining,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: controller.resendVerification,
              child: Text(
                '재발송',
                style: TextStyle(
                  color: _accent,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      final sent = controller.isVerificationSent;
      final loading = controller.isLoading;
      final label = sent ? '인증 확인' : '인증 링크 보내기';
      final onPressed = loading
          ? null
          : (sent ? controller.verifyCode : controller.requestVerification);

      return SizedBox(
        height: 52.h,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            disabledBackgroundColor: _accent.withValues(alpha: 0.5),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.r),
            ),
          ),
          child: loading
              ? SizedBox(
                  width: 22.w,
                  height: 22.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.black),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!sent) ...[
                      SizedBox(width: 6.w),
                      Icon(Icons.arrow_forward, size: 18.sp),
                    ],
                  ],
                ),
        ),
      );
    });
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
}
