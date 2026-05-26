import 'package:flutter/material.dart';
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroImage(),
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildVerificationInfoBox(),
              const SizedBox(height: 20),
              _buildVerificationSection(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 20),
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
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF202521), Color(0xFF0A0A0A)],
        ),
        border: Border.all(color: _divider),
      ),
      child: const Center(
        child: Icon(
          Icons.sports_tennis,
          color: _accent,
          size: 56,
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
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '회원가입 - 이메일 인증',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
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
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: _accent,
      decoration: const InputDecoration(
        hintText: '이메일을 입력하세요',
        hintStyle: TextStyle(color: _hint, fontSize: 15),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _divider),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _accent, width: 1.4),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildVerificationInfoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lock_outline, color: _accent, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '보안 인증 링크를 이메일로 보내드립니다. 비밀번호 없이 첫 단계를 시작할 수 있습니다.',
              style: TextStyle(
                color: _subtle,
                fontSize: 12,
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: _accent,
            decoration: InputDecoration(
              hintText: '인증번호 입력',
              hintStyle: const TextStyle(color: _hint, fontSize: 15),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    controller.formattedRemaining,
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 13,
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
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: controller.resendVerification,
              child: const Text(
                '재발송',
                style: TextStyle(
                  color: _accent,
                  fontSize: 12,
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
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            disabledBackgroundColor: _accent.withValues(alpha: 0.5),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.black),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!sent) ...const [
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18),
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
        const Text(
          '이미 계정이 있으신가요? ',
          style: TextStyle(color: _subtle, fontSize: 13),
        ),
        GestureDetector(
          onTap: controller.goToLogin,
          child: const Text(
            '로그인',
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
}
