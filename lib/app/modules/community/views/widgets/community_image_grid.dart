import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';

/// 게시글 첨부 이미지 그리드 (1~5장).
///
/// 장수에 따라 레이아웃이 달라진다:
/// - 1장: 16:9 단일 이미지
/// - 2장: 1:1 두 칸
/// - 3장 이상: 2열 그리드에서 앞 4장만 그리고, 5장째부터는 마지막 칸에
///   `+N` 잔여 카운트를 덮는다 (뷰어는 이 태스크 범위가 아니다).
class CommunityImageGrid extends StatelessWidget {
  const CommunityImageGrid({super.key, required this.imageUrls});

  final List<String> imageUrls;

  /// 2열 그리드에 실제로 그리는 최대 칸 수
  static const int _maxTiles = 4;

  /// 타일 사이 간격
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: AspectRatio(aspectRatio: 16 / 9, child: _tile(imageUrls.first)),
      );
    }

    if (imageUrls.length == 2) {
      return Row(
        children: [
          Expanded(child: _squareTile(imageUrls[0])),
          SizedBox(width: _gap.w),
          Expanded(child: _squareTile(imageUrls[1])),
        ],
      );
    }

    final visible = imageUrls.take(_maxTiles).toList();
    final remaining = imageUrls.length - visible.length;

    return Column(
      children: [
        for (int row = 0; row < (visible.length + 1) ~/ 2; row++) ...[
          if (row > 0) SizedBox(height: _gap.h),
          Row(
            children: [
              Expanded(
                child: _squareTile(
                  visible[row * 2],
                  // 마지막 칸에만 잔여 카운트를 덮는다.
                  overlayCount:
                      _isLastTile(row * 2, visible.length) ? remaining : 0,
                ),
              ),
              SizedBox(width: _gap.w),
              Expanded(
                child:
                    row * 2 + 1 < visible.length
                        ? _squareTile(
                          visible[row * 2 + 1],
                          overlayCount:
                              _isLastTile(row * 2 + 1, visible.length)
                                  ? remaining
                                  : 0,
                        )
                        // 3장일 때 남는 칸 — 비워서 정사각 비율을 유지한다.
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static bool _isLastTile(int index, int visibleLength) =>
      index == visibleLength - 1;

  Widget _squareTile(String url, {int overlayCount = 0}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _tile(url),
            if (overlayCount > 0)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: Text(
                  '+$overlayCount',
                  style: AppTypography.labelLg.copyWith(
                    fontSize: 20.sp,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.cardBg,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 24.sp,
        color: AppColors.subtleText,
      ),
    );
  }
}
