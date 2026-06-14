import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/news_card_response.dart';
import 'widgets/news_card_item.dart';

/// 카드뉴스 상세 화면.
///
/// 가로 슬라이드 리스트에서 한 장의 카드를 탭하면 진입하며,
/// 해당 기사의 2번째 카드 이미지(card-02)만 9:16 비율로 노출한다.
class NewsCardDetailView extends StatelessWidget {
  const NewsCardDetailView({super.key, required this.card});

  final NewsCardResponse card;

  static const Color _accent = Color(0xFFC3F400);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    final urls = card.imageUrls;
    // 두 번째 카드 이미지(인덱스 1). 없으면 첫 번째로 폴백.
    final String? imageUrl = urls.length >= 2
        ? urls[1]
        : (urls.isNotEmpty ? urls.first : null);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '뉴스 상세',
          style: TextStyle(
            color: _accent,
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w900,
            fontSize: 18.sp,
            letterSpacing: 0.6,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: imageUrl == null
                ? _empty()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final maxHeight = constraints.maxHeight;
                      // 9:16 비율 유지하면서 가용 영역에 맞게 축소.
                      double w = maxWidth;
                      double h = w * 16 / 9;
                      if (h > maxHeight) {
                        h = maxHeight;
                        w = h * 9 / 16;
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: w,
                          height: h,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: w,
                            height: h,
                            color: const Color(0xFF222121),
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 30.w,
                              height: 30.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accent,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: w,
                            height: h,
                            color: const Color(0xFF222121),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 36.sp,
                              color: NewsCardItem.subtleText,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.image_not_supported_outlined,
          size: 36.sp,
          color: NewsCardItem.subtleText,
        ),
        SizedBox(height: 10.h),
        Text(
          '표시할 이미지가 없습니다.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            color: Colors.white,
            fontSize: 13.sp,
          ),
        ),
      ],
    );
  }
}
