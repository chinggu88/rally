import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../data/models/notification_response.dart';
import '../controllers/notifications_controller.dart';

/// 알림 목록 화면.
class NotificationsView extends GetView<NotificationsController> {
  const NotificationsView({super.key});

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
          '알림',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading && controller.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentLime),
            );
          }
          if (controller.errorMessage != null && controller.items.isEmpty) {
            return _buildMessage(controller.errorMessage!, retry: true);
          }
          if (controller.items.isEmpty) {
            return _buildMessage('아직 받은 알림이 없어요.');
          }
          return RefreshIndicator(
            color: AppColors.accentLime,
            backgroundColor: AppColors.cardBg,
            onRefresh: controller.load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              itemCount: controller.items.length,
              separatorBuilder: (_, __) =>
                  Divider(color: AppColors.divider, height: 1.h),
              itemBuilder: (_, i) => _buildItem(controller.items[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildItem(NotificationResponse n) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(
              _iconForType(n.type),
              color: AppColors.accentLime,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  n.body,
                  style: TextStyle(
                    color: AppColors.subtleText,
                    fontSize: 13.sp,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  _formatRelativeTime(n.displayTime),
                  style: TextStyle(
                    color: AppColors.hint,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, {bool retry = false}) {
    return Center(
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
                foregroundColor: AppColors.accentLime,
                side: const BorderSide(color: AppColors.accentLime),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'ranking_change':
        return Icons.trending_up;
      default:
        return Icons.notifications_none;
    }
  }

  String _formatRelativeTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}
