import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/community_post_response.dart';
import '../../controllers/community_controller.dart';

/// 커뮤니티 게시글 단일 카드 (매거진 톤 — `_PlayerCard` 구조 준용).
///
/// ```
/// 장비 · 스매시왕 · 1시간 전
/// 아스트록스 100ZZ 후기          [썸네일]
/// 3개월 써본 소감 정리...
/// ♥51 💬17 👁240
/// ```
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({super.key, required this.post, required this.onTap});

  final CommunityPostResponse post;
  final VoidCallback onTap;

  static const double _thumbSize = 72;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = post.thumbnailUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.cardBorder),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMetaRow(),
                    SizedBox(height: 8.h),
                    Text(
                      (post.title ?? '').trim().isEmpty
                          ? '제목 없음'
                          : post.title!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.chivo,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                        height: 1.3,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      (post.content ?? '').trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        fontSize: 14.sp,
                        height: 1.4,
                        color: AppColors.subtleText,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    _buildMetricsRow(),
                  ],
                ),
              ),
              if (thumbnailUrl != null) ...[
                SizedBox(width: 12.w),
                _buildThumbnail(thumbnailUrl),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 카테고리 · 작성자 · 상대 시간
  Widget _buildMetaRow() {
    final category = post.category;
    return Row(
      children: [
        if (category != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              CommunityController.labelKoOf(category),
              style: AppTypography.labelLg.copyWith(
                fontSize: 11.sp,
                letterSpacing: 0.2,
                color: AppColors.accent,
              ),
            ),
          ),
        if (category != null) SizedBox(width: 8.w),
        Flexible(
          child: Text(
            post.authorDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              fontSize: 12.sp,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          '· ${_formatRelativeTime(post.createdAt)}',
          style: AppTypography.labelLg.copyWith(
            fontSize: 12.sp,
            letterSpacing: 0.2,
            color: AppColors.subtleText,
          ),
        ),
      ],
    );
  }

  /// 좋아요 · 댓글 · 조회
  Widget _buildMetricsRow() {
    return Row(
      children: [
        _metric(
          post.isLiked == true ? Icons.favorite : Icons.favorite_border,
          post.likeCount ?? 0,
          highlight: post.isLiked == true,
        ),
        SizedBox(width: 14.w),
        _metric(Icons.mode_comment_outlined, post.commentCount ?? 0),
        SizedBox(width: 14.w),
        _metric(Icons.visibility_outlined, post.viewCount ?? 0),
      ],
    );
  }

  Widget _metric(IconData icon, int count, {bool highlight = false}) {
    final color = highlight ? AppColors.accent : AppColors.subtleText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 4.w),
        Text(
          '$count',
          style: AppTypography.labelLg.copyWith(
            fontSize: 12.sp,
            letterSpacing: 0.2,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: CachedNetworkImage(
        imageUrl: url,
        width: _thumbSize.w,
        height: _thumbSize.w,
        fit: BoxFit.cover,
        placeholder: (_, __) => _thumbPlaceholder(),
        errorWidget: (_, __, ___) => _thumbPlaceholder(),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: _thumbSize.w,
      height: _thumbSize.w,
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 20.sp,
        color: AppColors.subtleText,
      ),
    );
  }

  /// 상대 시간 표기 (`notifications_view` 와 동일한 규칙)
  static String _formatRelativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
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
