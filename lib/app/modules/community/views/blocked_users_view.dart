import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/blocked_user_response.dart';
import '../controllers/blocked_users_controller.dart';

/// 차단한 사용자 목록 화면 (내정보 → 차단한 사용자).
///
/// **Apple App Review Guideline 1.2 요건이다.** 차단은 걸 수 있는 것만으로는
/// 부족하고, 사용자가 자기가 건 차단을 확인하고 되돌릴 수 있어야 한다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `FavoritePlayersView`
/// 의 리스트 구조(아바타 + 이름 + 우측 액션 + Divider)를 그대로 준용했다.
class BlockedUsersView extends GetView<BlockedUsersController> {
  const BlockedUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '차단한 사용자',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final users = controller.blockedUsers;
          if (controller.isLoading && users.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          final error = controller.errorMessage;
          if (error != null && users.isEmpty) {
            return _buildMessage(error, retry: true);
          }
          if (users.isEmpty) {
            return _buildMessage('차단한 사용자가 없습니다.');
          }
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.cardBg,
            onRefresh: controller.load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              itemCount: users.length,
              separatorBuilder:
                  (_, __) => Divider(color: AppColors.divider, height: 1.h),
              itemBuilder: (_, i) => _buildItem(users[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildItem(BlockedUserResponse user) {
    final avatarUrl = user.avatarUrl;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: AppColors.surfaceAlt,
            backgroundImage:
                (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
            child:
                (avatarUrl == null || avatarUrl.trim().isEmpty)
                    ? Icon(
                      Icons.person,
                      color: AppColors.subtleText,
                      size: 22.sp,
                    )
                    : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user.createdAt != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    '${_formatDate(user.createdAt!)} 차단',
                    style: TextStyle(
                      color: AppColors.subtleText,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _buildUnblockButton(user),
        ],
      ),
    );
  }

  Widget _buildUnblockButton(BlockedUserResponse user) {
    return Obx(() {
      final busy = controller.unblockingId == user.blockedId;
      return SizedBox(
        height: 34.h,
        child: OutlinedButton(
          onPressed: busy ? null : () => controller.unblock(user),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            disabledForegroundColor: AppColors.muted,
            side: BorderSide(
              color: busy ? AppColors.inactive : AppColors.accent,
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999.r),
            ),
          ),
          child:
              busy
                  ? SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: const CircularProgressIndicator(
                      color: AppColors.subtleText,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    '차단 해제',
                    style: AppTypography.labelLg.copyWith(
                      fontSize: 12.sp,
                      letterSpacing: 0.2,
                    ),
                  ),
        ),
      );
    });
  }

  Widget _buildMessage(String text, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtleText,
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            if (retry) ...[
              SizedBox(height: 16.h),
              OutlinedButton(
                onPressed: controller.load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
                child: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}.${two(time.month)}.${two(time.day)}';
  }
}
