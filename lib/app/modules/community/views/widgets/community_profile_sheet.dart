import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../controllers/community_profile_controller.dart';

/// 작성자 프로필 바텀시트 — **보기 전용**이다.
///
/// ```
/// ┌─────────────────────────────┐
/// │           ──                │  드래그 핸들
/// │          ◯ 아바타 72         │
/// │         스매시왕             │
/// │      2026년 6월 가입         │
/// └─────────────────────────────┘
/// ```
///
/// 액션 버튼이 없다. 신고·차단은 기존 더보기(⋯) 시트
/// (`CommunityMoreSheet`)가 창구이고, 여기에 같은 항목을 또 두지 않는다.
/// 닫기는 시트 바깥 탭 / 아래로 스와이프(`Get.bottomSheet` 기본 동작)다.
///
/// 이미 화면에 보이던 아바타·닉네임을 `fallback` 으로 받아 **로딩 중에도 먼저
/// 그린다** — 탭한 순간 알던 정보가 사라졌다 다시 나타나면 깜빡임으로 보인다.
/// 아직 모르는 가입일 자리만 스켈레톤이다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `CommunityMoreSheet`
/// 의 배경·라운딩·핸들과 상세 화면 아바타 스타일을 그대로 준용했다.
class CommunityProfileSheet extends GetView<CommunityProfileController> {
  const CommunityProfileSheet({super.key});

  /// 시트를 띄운다. 컨트롤러는 여기서 만들고 닫힐 때 정리한다.
  static Future<void> show({
    required String userId,
    String? fallbackNickname,
    String? fallbackAvatarUrl,
  }) async {
    Get.put(
      CommunityProfileController(
        userId: userId,
        fallbackNickname: fallbackNickname,
        fallbackAvatarUrl: fallbackAvatarUrl,
      ),
    );
    try {
      await Get.bottomSheet<void>(
        const CommunityProfileSheet(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } finally {
      await Get.delete<CommunityProfileController>(force: true);
    }
  }

  /// 아바타 지름
  static const double _avatarSize = 72;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGrabber(),
            SizedBox(height: 16.h),
            Obx(() => _buildAvatar(controller.avatarUrl)),
            SizedBox(height: 12.h),
            Obx(() => _buildName(controller.displayName)),
            SizedBox(height: 6.h),
            Obx(() => _buildSubline()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Container(
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: AppColors.inactive,
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    return ClipOval(
      child: SizedBox(
        width: _avatarSize.w,
        height: _avatarSize.w,
        child:
            (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                ? CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _avatarPlaceholder(),
                  errorWidget: (_, __, ___) => _avatarPlaceholder(),
                )
                : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 36.sp, color: AppColors.subtleText),
    );
  }

  Widget _buildName(String? name) {
    if (name == null || name.isEmpty) return _skeleton(120);
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTypography.chivo,
        fontWeight: FontWeight.w700,
        fontSize: 18.sp,
        height: 1.3,
        color: Colors.white,
      ),
    );
  }

  /// 닉네임 아래 한 줄 — 가입일 / 스켈레톤 / 에러 문구.
  ///
  /// `created_at` 이 없는 행은 줄 자체를 숨긴다(빈 문자열·`null` 을 노출하지
  /// 않는다).
  Widget _buildSubline() {
    final error = controller.errorMessage;
    if (error != null) return _subtleText(error);
    if (controller.isLoading) return _skeleton(88);

    final joinedAt = controller.joinedAt;
    if (joinedAt == null) return const SizedBox.shrink();
    return _subtleText('${joinedAt.year}년 ${joinedAt.month}월 가입');
  }

  Widget _subtleText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTypography.bodyMd.copyWith(
        fontSize: 13.sp,
        color: AppColors.subtleText,
      ),
    );
  }

  Widget _skeleton(double width) {
    return Container(
      width: width.w,
      height: 14.h,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }
}
