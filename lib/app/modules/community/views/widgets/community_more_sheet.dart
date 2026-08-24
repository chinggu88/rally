import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';

/// 게시글·댓글의 더보기(⋯) 바텀시트.
///
/// 항목 구성은 세 갈래다 (기획서 §6-1):
///
/// | 조건 | 항목 |
/// |------|------|
/// | 본인 콘텐츠 | 수정 · 삭제 |
/// | 타인 콘텐츠 | 신고 · 이 사용자 차단 |
/// | 운영자 | + 숨기기 / 복구 / 강제 삭제 / 작성자 정지 / 신고 종결 |
///
/// **운영자용 화면을 따로 만들지 않는다.** 신고가 들어오면 운영자 폰으로 FCM
/// 이 오고, 알림을 눌러 들어온 그 화면에서 바로 조치가 끝나야 24시간 SLA 가
/// 지켜진다. 조치 항목을 여기 얹어 둔 이유다.
///
/// 상태를 갖지 않는다 — 무엇을 보여줄지는 호출부(컨트롤러)가 판정해 플래그와
/// 콜백으로 넘긴다. 콜백이 null 인 항목은 그리지 않는다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) 기존 상세 화면의
/// 더보기 시트 톤을 그대로 준용했다.
class CommunityMoreSheet extends StatelessWidget {
  const CommunityMoreSheet({
    super.key,
    required this.isMine,
    required this.isAdmin,
    required this.isHidden,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onBlock,
    this.onSetHidden,
    this.onSetVisible,
    this.onForceDelete,
    this.onBanAuthor,
    this.onResolveReports,
  });

  /// 시트를 띄운다. 항목 구성은 [CommunityMoreSheet] 문서 참조.
  static Future<void> show({
    required bool isMine,
    required bool isAdmin,
    required bool isHidden,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onReport,
    VoidCallback? onBlock,
    VoidCallback? onSetHidden,
    VoidCallback? onSetVisible,
    VoidCallback? onForceDelete,
    VoidCallback? onBanAuthor,
    VoidCallback? onResolveReports,
  }) async {
    await Get.bottomSheet<void>(
      CommunityMoreSheet(
        isMine: isMine,
        isAdmin: isAdmin,
        isHidden: isHidden,
        onEdit: onEdit,
        onDelete: onDelete,
        onReport: onReport,
        onBlock: onBlock,
        onSetHidden: onSetHidden,
        onSetVisible: onSetVisible,
        onForceDelete: onForceDelete,
        onBanAuthor: onBanAuthor,
        onResolveReports: onResolveReports,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// 본인 콘텐츠 여부 — 수정/삭제 대 신고/차단을 가른다.
  final bool isMine;

  /// 운영자 여부 (`is_app_admin()`). 관리자 항목 노출 조건.
  final bool isAdmin;

  /// 현재 숨김 상태인지. 숨기기/복구 중 하나만 보여주기 위한 값이다.
  final bool isHidden;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  // 운영자 전용
  final VoidCallback? onSetHidden;
  final VoidCallback? onSetVisible;
  final VoidCallback? onForceDelete;
  final VoidCallback? onBanAuthor;
  final VoidCallback? onResolveReports;

  @override
  Widget build(BuildContext context) {
    final userItems = <Widget>[
      if (isMine && onEdit != null)
        _item(icon: Icons.edit_outlined, label: '수정', onTap: onEdit!),
      if (isMine && onDelete != null)
        _item(
          icon: Icons.delete_outline,
          label: '삭제',
          color: AppColors.liveRed,
          onTap: onDelete!,
        ),
      if (!isMine && onReport != null)
        _item(icon: Icons.flag_outlined, label: '신고', onTap: onReport!),
      if (!isMine && onBlock != null)
        _item(
          icon: Icons.block,
          label: '이 사용자 차단',
          color: AppColors.liveRed,
          onTap: onBlock!,
        ),
    ];

    final adminItems = <Widget>[
      if (isAdmin && !isHidden && onSetHidden != null)
        _item(
          icon: Icons.visibility_off_outlined,
          label: '숨기기',
          onTap: onSetHidden!,
        ),
      if (isAdmin && isHidden && onSetVisible != null)
        _item(
          icon: Icons.visibility_outlined,
          label: '복구',
          onTap: onSetVisible!,
        ),
      if (isAdmin && onForceDelete != null)
        _item(
          icon: Icons.delete_forever_outlined,
          label: '강제 삭제',
          color: AppColors.liveRed,
          onTap: onForceDelete!,
        ),
      if (isAdmin && onBanAuthor != null)
        _item(
          icon: Icons.person_off_outlined,
          label: '작성자 정지',
          color: AppColors.liveRed,
          onTap: onBanAuthor!,
        ),
      if (isAdmin && onResolveReports != null)
        _item(icon: Icons.task_alt, label: '신고 종결', onTap: onResolveReports!),
    ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGrabber(),
            ...userItems,
            if (adminItems.isNotEmpty) ...[
              if (userItems.isNotEmpty) _buildAdminDivider(),
              ...adminItems,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Container(
      width: 40.w,
      height: 4.h,
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.inactive,
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }

  /// 일반 항목과 운영자 항목을 눈으로 구분해 준다. 운영자 계정에서만 보이는
  /// 구간이라는 걸 드러내야 실수로 누르는 일이 줄어든다.
  Widget _buildAdminDivider() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 4.h),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.divider, height: 1.h)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Text(
              '운영자',
              style: AppTypography.labelLg.copyWith(
                fontSize: 11.sp,
                letterSpacing: 0.4,
                color: AppColors.accent,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.divider, height: 1.h)),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tint = color ?? Colors.white;
    return ListTile(
      // 시트를 먼저 닫고 액션을 실행한다. 확인 다이얼로그가 시트 위에 겹쳐
      // 뜨면 다이얼로그를 닫을 때 시트도 함께 사라져 흐름이 끊긴다.
      onTap: () {
        Get.back<void>();
        onTap();
      },
      leading: Icon(icon, color: tint, size: 20.sp),
      title: Text(
        label,
        style: AppTypography.bodyMd.copyWith(fontSize: 15.sp, color: tint),
      ),
    );
  }
}
