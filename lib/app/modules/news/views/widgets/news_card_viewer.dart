import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../theme/app_typography.dart';

/// 카드뉴스 전체화면 뷰어.
///
/// 가로 스와이프로 카드를 넘기고, 핀치 줌(InteractiveViewer)으로 확대할 수 있다.
/// 우상단 닫기 버튼 또는 빈 영역 탭으로 닫는다.
class NewsCardViewer extends StatefulWidget {
  const NewsCardViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  static const Color _accent = Color(0xFFC3F400);

  @override
  State<NewsCardViewer> createState() => _NewsCardViewerState();
}

class _NewsCardViewerState extends State<NewsCardViewer> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: urls[index],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NewsCardViewer._accent,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // 닫기 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _CircleIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          // 하단 카운터
          if (urls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${urls.length}',
                    style: const TextStyle(
                      fontFamily: AppTypography.chivo,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
