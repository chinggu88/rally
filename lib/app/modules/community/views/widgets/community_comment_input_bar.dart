import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/repositories/community_comment_repository.dart';
import '../../controllers/community_post_detail_controller.dart';

/// 댓글 입력바 — 화면 하단 고정.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `LiveMatchChatView` 의
/// pill 입력창 + 라임 전송 버튼을 그대로 준용했다. 같은 "대화" 성격의 입력이라
/// 두 화면의 조작감이 어긋나지 않는 편이 낫다.
///
/// `Obx` 는 답글 헤더 / 전송 버튼으로 쪼갠다. 바 전체를 하나로 감싸면 글자를
/// 칠 때마다(`commentLength`) `TextField` 까지 다시 그린다.
class CommunityCommentInputBar extends GetView<CommunityPostDetailController> {
  const CommunityCommentInputBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final target = controller.replyTarget;
              if (target == null) return const SizedBox.shrink();
              return _buildReplyHeader(target.authorDisplayName);
            }),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
              child: _buildComposer(),
            ),
          ],
        ),
      ),
    );
  }

  /// 답글 모드 표시 — 누구에게 다는 답글인지와 취소(X).
  Widget _buildReplyHeader(String nickname) {
    return Container(
      width: double.infinity,
      color: AppColors.chipBg,
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 8.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '@$nickname에게 답글',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelLg.copyWith(
                fontSize: 12.sp,
                letterSpacing: 0.2,
                color: AppColors.accent,
              ),
            ),
          ),
          GestureDetector(
            onTap: controller.cancelReply,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(6.w),
              child: Icon(
                Icons.close_rounded,
                size: 16.sp,
                color: AppColors.subtleText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F1D),
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: controller.commentInput,
              focusNode: controller.commentFocusNode,
              minLines: 1,
              maxLines: 4,
              maxLength: CommunityCommentRepository.maxContentLength,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              onChanged: controller.onCommentChanged,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              cursorColor: AppColors.accentLime,
              decoration: InputDecoration(
                counterText: '',
                hintText: '댓글을 입력해주세요',
                hintStyle: TextStyle(color: AppColors.hint, fontSize: 14.sp),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Obx(() {
            final isSending = controller.isSubmittingComment;
            // 빈 입력으로 눌러 스낵바만 뜨는 헛손질을 막는다.
            final canSend = !isSending && controller.commentLength.value > 0;
            return _buildSendButton(canSend: canSend, isSending: isSending);
          }),
        ],
      ),
    );
  }

  Widget _buildSendButton({required bool canSend, required bool isSending}) {
    return GestureDetector(
      onTap: canSend ? controller.submitComment : null,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: canSend ? AppColors.accentLime : AppColors.inactive,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow:
              canSend
                  ? [
                    BoxShadow(
                      color: AppColors.accentLime.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ]
                  : null,
        ),
        alignment: Alignment.center,
        child:
            isSending
                ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1A1F00),
                  ),
                )
                : Icon(
                  Icons.send_rounded,
                  color:
                      canSend ? const Color(0xFF1A1F00) : AppColors.subtleText,
                  size: 20.sp,
                ),
      ),
    );
  }
}
