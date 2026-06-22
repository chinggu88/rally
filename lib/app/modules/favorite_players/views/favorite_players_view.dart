import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../data/models/favorite_player_response.dart';
import '../controllers/favorite_players_controller.dart';

/// 좋아하는 선수 목록 화면.
class FavoritePlayersView extends GetView<FavoritePlayersController> {
  const FavoritePlayersView({super.key});

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
          '좋아하는 선수',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading && controller.players.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentLime),
            );
          }
          if (controller.errorMessage != null && controller.players.isEmpty) {
            return _buildMessage(controller.errorMessage!, retry: true);
          }
          if (controller.players.isEmpty) {
            return _buildMessage('아직 좋아하는 선수가 없어요.\n선수 화면에서 하트를 눌러 추가해보세요.');
          }
          return RefreshIndicator(
            color: AppColors.accentLime,
            backgroundColor: AppColors.cardBg,
            onRefresh: controller.load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              itemCount: controller.players.length,
              separatorBuilder: (_, __) =>
                  Divider(color: AppColors.divider, height: 1.h),
              itemBuilder: (_, i) => _buildItem(controller.players[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildItem(FavoritePlayerResponse p) {
    final photo = p.photoUrl;
    return InkWell(
      onTap: () => controller.openDetail(p),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: AppColors.cardBg,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? CachedNetworkImageProvider(photo)
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? Icon(Icons.person, color: AppColors.subtleText, size: 24.sp)
                  : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.playerName ?? '-',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (p.countryCode != null && p.countryCode!.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      p.countryCode!,
                      style: TextStyle(color: AppColors.subtleText, fontSize: 12.sp),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => controller.remove(p.playerId),
              icon: Icon(Icons.favorite, color: AppColors.accentLime, size: 22.sp),
            ),
          ],
        ),
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
            style: TextStyle(color: AppColors.subtleText, fontSize: 14.sp, height: 1.5),
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
