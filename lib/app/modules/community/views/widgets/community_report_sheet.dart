import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/create_community_report_parameter.dart';

/// 신고 바텀시트 (기획서 §6-2).
///
/// 사유 6종 라디오 + 상세 500자 + 제출. 제출에 성공하면 시트를 닫지 않고
/// **"이 사용자 차단하기" CTA 로 전환**한다 — 신고 처리는 운영자 몫이라
/// 결과가 바로 보이지 않는데, 차단은 그 자리에서 즉시 효과가 나므로
/// 신고자가 체감하는 처리 시간이 0초가 된다. Apple 리뷰어가 실제로 확인하는
/// 흐름이기도 하다.
///
/// 반응형 상태를 위젯이 직접 들고 있다. 시트가 열려 있는 동안만 사는 상태라
/// 컨트롤러를 새로 만들 이유가 없고, `RxString` 을 **시트 안쪽 `Obx` 에서
/// 직접 읽어야** `improper use of a GetX` 경고가 나지 않는다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `CommunityEulaSheet`
/// 의 시트 톤(그래버 + 라임 CTA)을 준용했다.
class CommunityReportSheet extends StatefulWidget {
  const CommunityReportSheet({
    super.key,
    required this.targetLabel,
    required this.onSubmit,
    this.onBlock,
  });

  /// 시트를 띄운다.
  ///
  /// [onSubmit] 은 성공 여부를 돌려준다 — true 면 완료 화면으로 전환하고,
  /// false 면 시트를 그대로 둔 채 (호출부가 띄운) 스낵바만 보여준다.
  /// 재신고(23505)처럼 되돌아와 고칠 것이 없는 실패에서도 입력을 잃지 않는다.
  ///
  /// [onBlock] 이 null 이면 완료 화면에 차단 CTA 를 그리지 않는다
  /// (작성자를 알 수 없는 경우 — 탈퇴한 사용자 등).
  static Future<void> show({
    required String targetLabel,
    required Future<bool> Function(String reason, String? detail) onSubmit,
    Future<void> Function()? onBlock,
  }) async {
    await Get.bottomSheet<void>(
      CommunityReportSheet(
        targetLabel: targetLabel,
        onSubmit: onSubmit,
        onBlock: onBlock,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// 신고 대상 표기 — '게시글' / '댓글' / '사용자'
  final String targetLabel;

  final Future<bool> Function(String reason, String? detail) onSubmit;
  final Future<void> Function()? onBlock;

  @override
  State<CommunityReportSheet> createState() => _CommunityReportSheetState();
}

class _CommunityReportSheetState extends State<CommunityReportSheet> {
  /// 선택된 사유 코드. 빈 문자열이면 미선택 — 제출 버튼이 비활성이다.
  final RxString _reason = ''.obs;

  /// 상세 입력 길이 — 카운터 표시용
  final RxInt _detailLength = 0.obs;

  final RxBool _isSubmitting = false.obs;

  /// 접수 완료 화면(차단 CTA)으로 전환됐는지
  final RxBool _isDone = false.obs;

  final TextEditingController _detailController = TextEditingController();

  @override
  void dispose() {
    _detailController.dispose();
    _reason.close();
    _detailLength.close();
    _isSubmitting.close();
    _isDone.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 키보드가 올라와도 제출 버튼이 가려지지 않도록 시트를 인셋만큼 밀어 올린다.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: SafeArea(
            top: false,
            // 접수 전/후로 시트 내용이 통째로 바뀐다. 이 Obx 하나가 전환을
            // 담당하고, 사유 선택·제출 상태는 안쪽의 작은 Obx 들이 맡는다.
            child: Obx(
              () => _isDone.value ? _buildDoneBody() : _buildFormBody(),
            ),
          ),
        ),
      ),
    );
  }

  // ── 입력 화면 ─────────────────────────────────────────────────────────

  Widget _buildFormBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGrabber(),
        _buildHeader('${widget.targetLabel} 신고'),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '신고 사유를 선택해주세요.',
                  style: AppTypography.bodyMd.copyWith(
                    fontSize: 13.sp,
                    color: AppColors.subtleText,
                  ),
                ),
                SizedBox(height: 10.h),
                _buildReasonList(),
                SizedBox(height: 16.h),
                _buildDetailLabel(),
                SizedBox(height: 6.h),
                _buildDetailField(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
          child: _buildSubmitButton(),
        ),
      ],
    );
  }

  /// 사유 라디오 6종. `_reason` 을 이 `Obx` 안에서 직접 읽는다.
  Widget _buildReasonList() {
    return Obx(() {
      final selected = _reason.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry
              in CreateCommunityReportParameter.reasonLabels.entries)
            _buildReasonRow(
              code: entry.key,
              label: entry.value,
              isSelected: entry.key == selected,
            ),
        ],
      );
    });
  }

  Widget _buildReasonRow({
    required String code,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _reason.value = code,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 2.w),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20.sp,
              color: isSelected ? AppColors.accent : AppColors.subtleText,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMd.copyWith(
                  fontSize: 14.sp,
                  color: isSelected ? Colors.white : AppColors.subtleText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailLabel() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '상세 내용 (선택)',
            style: AppTypography.labelLg.copyWith(
              fontSize: 13.sp,
              color: AppColors.subtleText,
            ),
          ),
        ),
        Obx(
          () => Text(
            '${_detailLength.value}'
            '/${CreateCommunityReportParameter.maxDetailLength}',
            style: AppTypography.labelLg.copyWith(
              fontSize: 11.sp,
              color: AppColors.subtleText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailField() {
    return TextField(
      controller: _detailController,
      onChanged: (value) => _detailLength.value = value.runes.length,
      maxLines: 4,
      maxLength: CreateCommunityReportParameter.maxDetailLength,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        counterText: '',
        hintText: '어떤 점이 문제인지 알려주시면 처리에 도움이 됩니다.',
        hintStyle: TextStyle(color: AppColors.hint, fontSize: 13.sp),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      final submitting = _isSubmitting.value;
      final enabled = _reason.value.isNotEmpty && !submitting;
      return SizedBox(
        height: 52.h,
        child: ElevatedButton(
          onPressed: enabled ? _submit : null,
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
                    '신고하기',
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

  Future<void> _submit() async {
    if (_isSubmitting.value) return;
    final reason = _reason.value;
    if (reason.isEmpty) return;

    _isSubmitting.value = true;
    try {
      final detail = _detailController.text.trim();
      final ok = await widget.onSubmit(reason, detail.isEmpty ? null : detail);
      if (ok) _isDone.value = true;
    } finally {
      // 위젯이 이미 dispose 됐으면(시트가 닫힌 뒤 응답 도착) 닫힌 Rx 를
      // 건드리지 않는다.
      if (mounted) _isSubmitting.value = false;
    }
  }

  // ── 접수 완료 화면 ────────────────────────────────────────────────────

  Widget _buildDoneBody() {
    final onBlock = widget.onBlock;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGrabber(),
        _buildHeader('신고가 접수되었습니다'),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 4.h),
          child: Text(
            '접수된 신고는 운영자가 24시간 이내에 확인합니다.\n'
            '해당 사용자의 글과 댓글을 더 보고 싶지 않다면 차단할 수 있습니다.',
            style: AppTypography.bodyMd.copyWith(
              fontSize: 13.sp,
              height: 1.6,
              color: AppColors.subtleText,
            ),
          ),
        ),
        SizedBox(height: 18.h),
        if (onBlock != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: SizedBox(
              height: 52.h,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.back<void>();
                  onBlock();
                },
                icon: Icon(Icons.block, size: 18.sp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                ),
                label: Text(
                  '이 사용자 차단하기',
                  style: TextStyle(
                    fontFamily: AppTypography.chivo,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.sp,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
          child: SizedBox(
            height: 48.h,
            child: TextButton(
              onPressed: () => Get.back<void>(),
              child: Text(
                '닫기',
                style: AppTypography.bodyMd.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.subtleText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 공통 ──────────────────────────────────────────────────────────────

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

  Widget _buildHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 6.h, 8.w, 14.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Get.back<void>(),
            icon: Icon(Icons.close, color: AppColors.subtleText, size: 22.sp),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }
}
