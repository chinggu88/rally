import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/live_match_response.dart';
import '../controllers/news_controller.dart';
import 'widgets/live_match_card.dart';

/// 홈(뉴스) 화면.
///
/// 바텀 네비게이션 첫 번째 탭이며, 사용자 확정으로 "뉴스 = 홈"이다.
/// 화면 상단에 라이브 매치 캐러셀이 고정되고, 그 아래 뉴스 영역(현재 placeholder)이
/// 표시된다. Pull-to-refresh로 라이브 매치를 재조회한다.
class NewsView extends GetView<NewsController> {
  const NewsView({super.key});

  // 매거진 디자인 토큰 (Stitch 시안과 정합되는 미세 디테일).
  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: controller.refreshLiveMatches,
          color: _accent,
          backgroundColor: scheme.surfaceContainer,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(child: _buildLiveSection(context, scheme)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildNewsPlaceholder(scheme)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.dark.surface,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      centerTitle: false,
      title: const Text(
        'Kinetic Court',
        style: TextStyle(
          color: _accent,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ── 라이브 섹션 ─────────────────────────────────────────
  Widget _buildLiveSection(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: 10),
        Obx(() => _buildLiveBody(context, scheme)),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D4F),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '라이브 매치',
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Obx(() {
            final count = controller.liveMatches.length;
            if (count == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: _accentDark,
                  letterSpacing: 0.4,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLiveBody(BuildContext context, ColorScheme scheme) {
    if (controller.isLiveLoading && controller.liveMatches.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    final error = controller.liveError;
    if (error != null && controller.liveMatches.isEmpty) {
      return _buildErrorState(error);
    }

    if (controller.liveMatches.isEmpty) {
      return _buildEmptyState();
    }

    return _buildCarousel(context, controller.liveMatches);
  }

  Widget _buildCarousel(BuildContext context, List<LiveMatchResponse> matches) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.85).clamp(280.0, 360.0);

    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = matches[index];
          return LiveMatchCard(
            match: m,
            width: cardWidth,
            // 추후 detail_url 외부 오픈 자리 — 현재는 no-op.
            onTap: () {},
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: _subtleText),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: controller.refreshLiveMatches,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _accentDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sports_tennis_outlined,
              size: 36,
              color: _subtleText,
            ),
            const SizedBox(height: 10),
            Text(
              '현재 진행 중인 라이브 매치가 없습니다.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '대회가 시작되면 여기에 실시간 스코어가 표시됩니다.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: _subtleText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 뉴스 placeholder ────────────────────────────────────
  Widget _buildNewsPlaceholder(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '뉴스',
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B1B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.newspaper_outlined,
                  size: 36,
                  color: _subtleText,
                ),
                const SizedBox(height: 10),
                Text(
                  '뉴스 콘텐츠 준비 중',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '곧 BWF 관련 소식을 만나보실 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: _subtleText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
