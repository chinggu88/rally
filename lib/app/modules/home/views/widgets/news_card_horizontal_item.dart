import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/news_card_response.dart';
import 'news_card_item.dart';

/// 가로 슬라이드 리스트에서 한 장의 카드뉴스를 표현하는 아이템.
///
/// 각 뉴스의 첫 번째(card-01) 이미지만 9:16 비율로 노출한다.
/// [sourceLabel]이 있으면 좌상단에 출처 배지를 표시한다.
class NewsCardHorizontalItem extends StatelessWidget {
  const NewsCardHorizontalItem({
    super.key,
    required this.card,
    required this.width,
    required this.onTap,
    this.sourceLabel,
  });

  final NewsCardResponse card;
  final double width;
  final VoidCallback onTap;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final coverUrl = card.coverUrl;
    final height = width * 16 / 9;
    final label = sourceLabel;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: width,
          height: height,
          color: NewsCardItem.cardBg,
          child: Stack(
            children: [
              Positioned.fill(
                child:
                    coverUrl == null
                        ? _placeholder()
                        : CachedNetworkImage(
                          imageUrl: coverUrl,
                          width: width,
                          height: height,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => Container(
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
                          errorWidget: (_, __, ___) => _placeholder(),
                        ),
              ),
              // if (label != null && label.isNotEmpty)
              //   Positioned(
              //     top: 10.h,
              //     left: 10.w,
              //     child: Container(
              //       padding:
              //           EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              //       decoration: BoxDecoration(
              //         color: Colors.black.withValues(alpha: 0.55),
              //         borderRadius: BorderRadius.circular(999.r),
              //       ),
              //       child: Text(
              //         label,
              //         style: TextStyle(
              //           fontFamily: AppTypography.chivo,
              //           fontWeight: FontWeight.w700,
              //           fontSize: 10.sp,
              //           letterSpacing: 0.2,
              //           color: Colors.white,
              //         ),
              //       ),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 32.sp,
        color: NewsCardItem.subtleText,
      ),
    );
  }
}
