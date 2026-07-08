import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/news_card_response.dart';
import 'news_card_viewer.dart';

/// 카드뉴스 1건(기사)을 표현하는 피드 아이템.
///
/// 한 기사는 여러 장의 세로형(9:16) 카드 이미지로 구성된다.
/// 가로 스와이프로 카드를 넘기고, 하단에 점 인디케이터 + "현재/전체" 카운터를 둔다.
/// 카드를 탭하면 전체화면 뷰어([NewsCardViewer])로 확대해 본다.
class NewsCardItem extends StatefulWidget {
  const NewsCardItem({super.key, required this.card});

  final NewsCardResponse card;

  // 매거진 디자인 토큰 (HomeView와 정합).
  static const Color accent = AppColors.accent;
  static const Color cardBg = AppColors.cardBg;
  static const Color border = AppColors.cardBorder;
  static const Color subtleText = AppColors.subtleText;

  @override
  State<NewsCardItem> createState() => _NewsCardItemState();
}

class _NewsCardItemState extends State<NewsCardItem> {
  static const Color _inactive = Color(0xFF3A3A3A);

  // 9:16 카드가 피드에서 과하게 커지지 않도록 높이 상한을 둔다.
  static const double _maxCardHeight = 560;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.card.imageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    // 좌우 패딩 20씩 가정한 카드 폭.
    final cardWidth = screenWidth - 40;
    final naturalHeight = cardWidth * 16 / 9;
    final cardHeight = naturalHeight.clamp(0.0, _maxCardHeight);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        color: NewsCardItem.cardBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: cardHeight,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      return _CardImage(
                        url: urls[index],
                        onTap: () => _openViewer(context, urls, index),
                      );
                    },
                  ),
                  // 현재/전체 카운터 (카드가 2장 이상일 때만)
                  if (urls.length > 1)
                    Positioned(
                      top: 12.h,
                      right: 12.w,
                      child: _CountBadge(
                        current: _currentPage + 1,
                        total: urls.length,
                      ),
                    ),
                ],
              ),
            ),
            if (urls.length > 1) ...[
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: active ? 18.w : 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: active ? NewsCardItem.accent : _inactive,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  );
                }),
              ),
              SizedBox(height: 12.h),
            ],
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => NewsCardViewer(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

/// 단일 카드 이미지(9:16). 탭하면 [onTap] 콜백.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: SizedBox(
            width: 26.w,
            height: 26.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: NewsCardItem.accent,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            size: 28.sp,
            color: NewsCardItem.subtleText,
          ),
        ),
      ),
    );
  }
}

/// "1 / 3" 형태의 카운터 배지.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        '$current / $total',
        style: TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 11.sp,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}
