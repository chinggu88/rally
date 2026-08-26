import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import 'community_image_viewer.dart';

/// 게시글 첨부 이미지 그리드 (1~5장).
///
/// 장수에 따라 레이아웃이 달라진다:
/// - 1장: 원본 비율을 실측해 `3/4 ~ 16/9` 로 clamp한 단일 이미지
/// - 2장: 1:1 두 칸
/// - 3장 이상: 2열 그리드에서 앞 4장만 그리고, 5장째부터는 마지막 칸에
///   `+N` 잔여 카운트를 덮는다.
///
/// **TASK-016 에서 두 가지가 바뀌었다.**
/// 1. 1장 레이아웃이 고정 16:9 였다. 세로 사진이 위아래로 잘려서 실측 비율로
///    바꿨다 — [_AspectTile] 참조. 2장 이상은 격자가 어긋나지 않도록 정사각을
///    그대로 둔다.
/// 2. *"뷰어는 이 태스크 범위가 아니다"* 라고 적혀 있었으나 이제 있다.
///    모든 타일과 `+N` 오버레이가 [CommunityImageViewer] 진입점이며, 뷰어에는
///    그리드에 보이지 않는 5장째까지 **전체 목록**을 넘긴다.
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
      return _AspectTile(
        url: imageUrls.first,
        onTap: () => _openViewer(0),
      );
    }

    if (imageUrls.length == 2) {
      return Row(
        children: [
          Expanded(child: _squareTile(imageUrls[0], index: 0)),
          SizedBox(width: _gap.w),
          Expanded(child: _squareTile(imageUrls[1], index: 1)),
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
                  index: row * 2,
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
                          index: row * 2 + 1,
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

  /// `+N` 오버레이가 덮인 타일도 그대로 뷰어로 들어간다. 그리드에 보이는
  /// 4장만이 아니라 [imageUrls] 전체를 넘기므로 5장째도 스와이프로 볼 수 있다.
  void _openViewer(int index) {
    CommunityImageViewer.show(imageUrls: imageUrls, initialIndex: index);
  }

  Widget _squareTile(String url, {required int index, int overlayCount = 0}) {
    // 오버레이 Container 가 탭을 가로채지 않도록 타일 전체를 감싼다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openViewer(index),
      child: ClipRRect(
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
      ),
    );
  }

  /// [_AspectTile] 이 같은 이미지 렌더를 재사용하도록 static 으로 둔다.
  static Widget _tile(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  static Widget _placeholder() {
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

/// 1장짜리 본문 이미지 — 원본 비율을 실측해 [AspectRatio] 에 반영한다.
///
/// `community_posts.image_paths` 는 경로 배열뿐이라 **DB에 비율 메타데이터가
/// 없다.** 그래서 마이그레이션 없이 클라이언트에서 [ImageStream] 으로 실측한다.
///
/// 실측 전에는 [_placeholderRatio] 로 그린다 — clamp 범위의 중간값이라 실측
/// 후 레이아웃 이동 폭이 가장 작다. `BoxFit.cover` 는 유지한다. clamp 범위
/// 안에서는 잘림이 거의 없고, 범위를 벗어난 극단 비율만 제한적으로 잘린다.
class _AspectTile extends StatefulWidget {
  const _AspectTile({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  State<_AspectTile> createState() => _AspectTileState();
}

class _AspectTileState extends State<_AspectTile> {
  /// 9:16 같은 극단 세로 사진이 화면을 다 먹지 않도록 하한을 둔다.
  static const double _minRatio = 3 / 4;

  /// 21:9 같은 극단 가로 사진의 상한.
  static const double _maxRatio = 16 / 9;

  /// 실측 전 비율.
  static const double _placeholderRatio = 4 / 3;

  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _ratio;

  @override
  void initState() {
    super.initState();
    _resolveRatio();
  }

  @override
  void didUpdateWidget(covariant _AspectTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    _detachListener();
    _ratio = null;
    _resolveRatio();
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  void _resolveRatio() {
    final stream = CachedNetworkImageProvider(
      widget.url,
    ).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        final width = info.image.width;
        final height = info.image.height;
        // 리스너가 받는 ImageInfo 는 clone 이라 읽고 나면 직접 해제한다.
        info.dispose();
        if (!mounted || height == 0) return;
        setState(() {
          _ratio = (width / height).clamp(_minRatio, _maxRatio).toDouble();
        });
      },
      // 실측 실패는 치명적이지 않다 — placeholder 비율로 그대로 둔다.
      onError: (_, __) {},
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _detachListener() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: AspectRatio(
          aspectRatio: _ratio ?? _placeholderRatio,
          child: CommunityImageGrid._tile(widget.url),
        ),
      ),
    );
  }
}
