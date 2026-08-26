import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';

/// 게시글 첨부 이미지 전체화면 뷰어.
///
/// [CommunityImageGrid] 의 타일을 탭하면 열린다. 그리드는 최대 4칸만 그리지만
/// 뷰어는 **첨부된 전체 목록**을 받아 좌우 스와이프로 전부 볼 수 있게 한다.
///
/// 상태를 컨트롤러에 두지 않는다 — 이미지 URL 목록과 초기 인덱스만 받는
/// `StatefulWidget` 이라 GetX 컨트롤러를 새로 둘 이유가 없다.
///
/// **제스처 충돌 처리가 이 위젯의 핵심이다.** `InteractiveViewer` 로 확대한
/// 상태에서 드래그하면 `PageView` 가 페이지를 넘겨버려 사진을 움직일 수 없다.
/// 그래서 배율이 1을 넘는 동안 `PageView` 의 스크롤을 막고, 배율이 1로
/// 돌아오면 되돌린다. 페이지가 바뀌면 배율도 1로 초기화한다.
///
/// 배경은 `AppColors` 가 아니라 `Colors.black` 을 쓴다 — 사진 감상 화면의
/// 표준이며, 이 화면에서만 허용한 예외다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) 표준 풀스크린 갤러리
/// 패턴을 따랐다.
class CommunityImageViewer extends StatefulWidget {
  const CommunityImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  /// 뷰어를 띄운다. [imageUrls] 가 비어 있으면 아무것도 하지 않는다.
  static Future<void> show({
    required List<String> imageUrls,
    int initialIndex = 0,
  }) async {
    if (imageUrls.isEmpty) return;
    await Get.to<void>(
      () => CommunityImageViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
      fullscreenDialog: true,
      transition: Transition.fadeIn,
    );
  }

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<CommunityImageViewer> createState() => _CommunityImageViewerState();
}

class _CommunityImageViewerState extends State<CommunityImageViewer> {
  /// 확대 판정 임계값. 부동소수 오차로 1.0 을 살짝 넘는 값이 나올 수 있어
  /// 정확히 1과 비교하지 않는다.
  static const double _zoomEpsilon = 1.01;

  late final PageController _pageController;

  /// 페이지마다 새로 만들지 않고 하나를 공유한다. 확대 중에는 페이지 이동이
  /// 막혀 있어 인접 페이지가 확대된 채로 보일 일이 없다.
  final TransformationController _transformation = TransformationController();

  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _transformation.addListener(_handleTransformationChanged);
  }

  @override
  void dispose() {
    _transformation.removeListener(_handleTransformationChanged);
    _transformation.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleTransformationChanged() {
    final zoomed =
        _transformation.value.getMaxScaleOnAxis() > _zoomEpsilon;
    if (zoomed == _isZoomed) return;
    setState(() => _isZoomed = zoomed);
  }

  void _handlePageChanged(int index) {
    // 확대한 채 다음 장으로 넘어가면 다음 사진도 확대된 상태로 뜬다.
    _transformation.value = Matrix4.identity();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            // 확대 중에는 드래그가 페이지 넘김이 아니라 사진 이동이어야 한다.
            // 평상시에는 null 로 둬서 플랫폼 기본 physics 를 그대로 쓴다.
            physics: _isZoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: widget.imageUrls.length,
            itemBuilder: (_, index) => _buildPage(widget.imageUrls[index]),
          ),
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildPage(String url) {
    return InteractiveViewer(
      // 현재 보이는 페이지에만 변환이 적용되면 되므로 컨트롤러를 공유한다.
      transformationController: _transformation,
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          // 뷰어는 원본 전체를 보는 것이 목적이라 contain 이 맞다.
          fit: BoxFit.contain,
          placeholder: (_, __) => _buildPlaceholder(),
          errorWidget: (_, __, ___) => _buildError(),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: SizedBox(
        height: 48.h,
        child: Stack(
          children: [
            if (widget.imageUrls.length > 1)
              Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: AppTypography.labelLg.copyWith(
                    fontSize: 14.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: Get.back,
                icon: Icon(Icons.close, size: 24.sp, color: Colors.white),
                tooltip: '닫기',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: SizedBox(
        width: 24.w,
        height: 24.w,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.subtleText,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 40.sp,
            color: AppColors.subtleText,
          ),
          SizedBox(height: 8.h),
          Text(
            '이미지를 불러오지 못했습니다.',
            style: AppTypography.bodyMd.copyWith(
              fontSize: 13.sp,
              color: AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}
