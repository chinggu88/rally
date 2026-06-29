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
              itemBuilder: (_, i) =>
                  _NotificationTile(notification: controller.items[i]),
            ),
          );
        }),
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

}

/// 알림 1건 — 랭킹변동 요약이면 탭하여 선수별 상세를 인라인으로 펼친다.
class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.notification});

  final NotificationResponse notification;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _expanded = false;

  static const Map<String, String> _categoryLabel = {
    'MS': '남자 단식',
    'WS': '여자 단식',
    'MD': '남자 복식',
    'WD': '여자 복식',
    'XD': '혼합 복식',
  };

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final changes = n.rankingChanges;
    final hasDetail = changes.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasDetail
                ? () => setState(() => _expanded = !_expanded)
                : null,
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
                if (hasDetail)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.hint,
                    size: 22.sp,
                  ),
              ],
            ),
          ),
          if (hasDetail && _expanded) ...[
            SizedBox(height: 12.h),
            Container(
              margin: EdgeInsets.only(left: 54.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  for (final c in changes) _buildChangeRow(c),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangeRow(RankingChangeItem c) {
    final emoji = c.isUp ? '📈' : '📉';
    final verb = c.isUp ? '상승' : '하락';
    final cat = _categoryLabel[c.category] ?? c.category;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 8.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '${c.playerName} ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '($cat)\n',
                    style: TextStyle(
                      color: AppColors.subtleText,
                      fontSize: 12.sp,
                    ),
                  ),
                  TextSpan(
                    text:
                        '세계랭킹 ${c.rankChange.abs()}계단 $verb → 현재 ${c.rank}위',
                    style: TextStyle(
                      color: AppColors.subtleText,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
