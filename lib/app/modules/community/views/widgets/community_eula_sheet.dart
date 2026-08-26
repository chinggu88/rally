import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../controllers/community_onboarding_controller.dart';
import 'community_eula_markdown.dart';

/// 커뮤니티 시작하기 바텀시트 (기획서 S-6).
///
/// 닉네임 설정과 이용규칙 동의를 **한 화면에서** 받는다. 두 단계로 나누면
/// 첫 글을 쓰려던 사용자가 중간에 이탈한다. 닉네임이 이미 있으면 입력란은
/// 아예 그리지 않고 약관만 받는다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `SignUpView` 의
/// 언더라인 입력 필드 + 라임 CTA 톤을 준용했다.
///
/// `Obx` 는 입력란 / 상태 문구 / 체크박스 / 버튼으로 잘게 쪼갠다. 시트 전체를
/// 하나로 감싸면 타이핑할 때마다 이용규칙 본문까지 다시 그린다.
class CommunityEulaSheet extends GetView<CommunityOnboardingController> {
  const CommunityEulaSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // 키보드가 올라올 때 "동의하고 계속" 버튼이 가려지지 않도록 시트 자체를
    // 인셋만큼 밀어 올린다. isScrollControlled 와 짝을 이룬다.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGrabber(),
                  _buildHeader(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.needsNickname) ...[
                            _buildNicknameLabel(),
                            SizedBox(height: 4.h),
                            _buildNicknameField(),
                            SizedBox(height: 8.h),
                            _buildNicknameStatus(),
                            SizedBox(height: 20.h),
                          ],
                          _buildEulaBox(),
                          SizedBox(height: 12.h),
                          if (controller.needsAgreement) _buildAgreeCheckbox(),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
                    child: _buildSubmitButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
        decoration: BoxDecoration(
          color: AppColors.inactive,
          borderRadius: BorderRadius.circular(999.r),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 6.h, 8.w, 14.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '커뮤니티 시작하기',
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // 시트를 드래그·탭으로 닫을 수 없게 막아 뒀으므로(입력 유실 방지)
          // 명시적인 닫기 버튼이 반드시 있어야 한다.
          IconButton(
            onPressed: () => Get.back<bool>(),
            icon: Icon(Icons.close, color: AppColors.subtleText, size: 22.sp),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  // ── 닉네임 ────────────────────────────────────────────────────────────

  Widget _buildNicknameLabel() {
    return Text(
      '닉네임',
      style: AppTypography.labelLg.copyWith(
        fontSize: 13.sp,
        color: AppColors.subtleText,
      ),
    );
  }

  Widget _buildNicknameField() {
    return TextField(
      controller: controller.nicknameController,
      onChanged: controller.onNicknameChanged,
      textInputAction: TextInputAction.done,
      maxLength: CommunityOnboardingController.maxNicknameLength,
      style: TextStyle(color: Colors.white, fontSize: 16.sp),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        counterText: '',
        hintText: '2~12자로 입력해주세요',
        hintStyle: TextStyle(color: AppColors.hint, fontSize: 15.sp),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.accent, width: 1.4),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
      ),
    );
  }

  /// 검사 중 / 사용 가능 / 오류 한 줄. 반응형 변수를 이 Obx 안에서 직접 읽는다.
  Widget _buildNicknameStatus() {
    return Obx(() {
      if (controller.isCheckingNickname.value) {
        return _statusRow(
          icon: Icons.hourglass_empty,
          text: '확인 중...',
          color: AppColors.subtleText,
        );
      }
      final error = controller.nicknameError.value;
      if (error != null) {
        return _statusRow(
          icon: Icons.error_outline,
          text: error,
          color: AppColors.liveRed,
        );
      }
      if (controller.isNicknameAvailable.value) {
        return _statusRow(
          icon: Icons.check_circle_outline,
          text: '사용 가능한 닉네임입니다.',
          color: AppColors.accent,
        );
      }
      return _statusRow(
        icon: Icons.info_outline,
        text: '커뮤니티에서 표시될 이름입니다. 나중에 변경할 수 있습니다.',
        color: AppColors.subtleText,
      );
    });
  }

  Widget _statusRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMd.copyWith(fontSize: 12.sp, color: color),
          ),
        ),
      ],
    );
  }

  // ── 이용규칙 ──────────────────────────────────────────────────────────

  Widget _buildEulaBox() {
    return Container(
      height: 220.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Obx(() {
        if (controller.isEulaLoading.value) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
          );
        }
        return Scrollbar(
          child: SingleChildScrollView(
            child: CommunityEulaMarkdown(raw: controller.eulaText.value),
          ),
        );
      }),
    );
  }

  // ── 동의 · 제출 ───────────────────────────────────────────────────────

  Widget _buildAgreeCheckbox() {
    return Obx(() {
      final agreed = controller.isAgreed.value;
      return InkWell(
        onTap: () => controller.isAgreed.value = !agreed,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Row(
            children: [
              Icon(
                agreed ? Icons.check_box : Icons.check_box_outline_blank,
                size: 22.sp,
                color: agreed ? AppColors.accent : AppColors.subtleText,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '이용규칙에 동의합니다.',
                  style: AppTypography.bodyMd.copyWith(
                    fontSize: 14.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      final enabled = controller.canSubmit;
      final submitting = controller.isSubmitting.value;
      return SizedBox(
        height: 52.h,
        child: ElevatedButton(
          onPressed: enabled ? controller.submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.accentDark,
            disabledBackgroundColor: AppColors.inactive,
            disabledForegroundColor: AppColors.muted,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.r),
            ),
          ),
          child:
              submitting
                  ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      color: AppColors.accentDark,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    '동의하고 계속',
                    style: TextStyle(
                      fontFamily: AppTypography.chivo,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.sp,
                      letterSpacing: 0.4,
                    ),
                  ),
        ),
      );
    });
  }
}
