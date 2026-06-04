import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/active_tournament_response.dart';
import '../../../data/models/live_match_response.dart';
import '../controllers/news_controller.dart';
import 'widgets/active_tournament_card.dart';
import 'widgets/live_match_card.dart';
import 'widgets/news_card_item.dart';

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
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // 바닥 근처(400px 이내) 도달 시 다음 페이지 로드.
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 400) {
                controller.loadMoreNewsCards();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: Obx(() => _buildActiveTournamentsSection(context)),
                ),
                SliverToBoxAdapter(child: _buildLiveSection(context, scheme)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildNewsSection(context, scheme)),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
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

  // ── 남은 대회(진행중/예정) 섹션 ──────────────────────────
  Widget _buildActiveTournamentsSection(BuildContext context) {
    final loading = controller.isActiveTournamentsLoading;
    final tournaments = controller.activeTournaments;

    // 로딩 중이 아니고 보여줄 대회가 없으면 섹션 자체를 숨겨 상단을 비운다.
    if (!loading && tournaments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading && tournaments.isEmpty)
          const SizedBox(
            height: 44,
            child: Center(child: CircularProgressIndicator(color: _accent)),
          )
        else
          _buildActiveTournamentsList(tournaments),
        const SizedBox(height: 24),
      ],
    );
  }

  

  Widget _buildActiveTournamentsList(List<ActiveTournamentResponse> items) {
    // 서버(get-active-tournaments-kr)가 start_date ASC로 정렬해 내려주므로
    // 클라이언트에서 별도 정렬 없이 API 응답 순서를 그대로 사용한다.
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return Center(
            child: ActiveTournamentCard(
              key: ValueKey<Object>(
                items[index].tournamentId ?? 'tour-$index',
              ),
              tournament: items[index],
            ),
          );
        },
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
          const Spacer(),
          Obx(
            () => _RealtimeStatusDot(connected: controller.isRealtimeConnected),
          ),
          const SizedBox(width: 20 - 12), // 우측 여백(섹션 헤더 padding 보정)
        ],
      ),
    );
  }

  Widget _buildLiveBody(BuildContext context, ColorScheme scheme) {
    if (controller.isLiveLoading && controller.liveMatches.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: _accent)),
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
    // PageView viewportFraction: 카드 너비 + 좌우 여백을 자연스럽게 노출.
    final viewportFraction = (cardWidth + 16) / screenWidth;

    // court1 → court2 → court3 … 순서로 정렬.
    // 숫자가 없는 코트는 끝으로 보내고, 동률은 id 오름차순.
    final sorted = List<LiveMatchResponse>.from(matches)..sort((a, b) {
      final ca = _courtOrderKey(a.courtName);
      final cb = _courtOrderKey(b.courtName);
      final byCourt = ca.compareTo(cb);
      if (byCourt != 0) return byCourt;
      final ia = a.id ?? 1 << 30;
      final ib = b.id ?? 1 << 30;
      return ia.compareTo(ib);
    });

    return _LiveMatchPageView(
      matches: sorted,
      cardWidth: cardWidth,
      viewportFraction: viewportFraction.clamp(0.5, 1.0),
      controller: controller,
    );
  }

  /// court 이름에서 정렬 키를 추출.
  /// - "Court 1" / "court1" / "1 코트" → 1
  /// - 숫자가 없거나 비어있으면 매우 큰 값(끝으로) 반환
  int _courtOrderKey(String? courtName) {
    final raw = (courtName ?? '').trim();
    if (raw.isEmpty) return 1 << 30;
    final m = RegExp(r'(\d+)').firstMatch(raw);
    if (m == null) return 1 << 29; // 텍스트만 있는 코트는 숫자 코트 뒤
    return int.tryParse(m.group(1)!) ?? (1 << 29);
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

  // ── 뉴스(카드뉴스) 섹션 ──────────────────────────────────
  Widget _buildNewsSection(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const SizedBox(width: 8),
              Obx(() {
                final count = controller.newsCards.length;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
          const SizedBox(height: 12),
          Obx(() => _buildNewsBody(context)),
        ],
      ),
    );
  }

  Widget _buildNewsBody(BuildContext context) {
    if (controller.isNewsLoading && controller.newsCards.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final error = controller.newsError;
    if (error != null && controller.newsCards.isEmpty) {
      return _buildNewsErrorState(error);
    }

    if (controller.newsCards.isEmpty) {
      return _buildNewsEmptyState();
    }

    final cards = controller.newsCards;
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          NewsCardItem(
            key: ValueKey<Object>(cards[i].id ?? 'news-$i'),
            card: cards[i],
          ),
          if (i != cards.length - 1) const SizedBox(height: 20),
        ],
        // 더보기 로딩 인디케이터
        if (controller.isNewsLoadingMore) ...[
          const SizedBox(height: 20),
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
        ],
      ],
    );
  }

  Widget _buildNewsErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
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
              onPressed: controller.fetchNewsCards,
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

  Widget _buildNewsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          const Icon(Icons.newspaper_outlined, size: 36, color: _subtleText),
          const SizedBox(height: 10),
          Text(
            '아직 카드뉴스가 없습니다.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '새로운 소식이 준비되면 여기에 카드뉴스로 표시됩니다.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: _subtleText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 라이브 매치 카드 PageView.
///
/// - 가로 스와이프 시 한 장씩 스냅된다 (PageView 기본 동작).
/// - 좌우 카드의 일부가 보이도록 viewportFraction을 사용.
/// - 하단에 페이지 인디케이터(점)를 표시.
class _LiveMatchPageView extends StatefulWidget {
  const _LiveMatchPageView({
    required this.matches,
    required this.cardWidth,
    required this.viewportFraction,
    required this.controller,
  });

  final List<LiveMatchResponse> matches;
  final double cardWidth;
  final double viewportFraction;
  final NewsController controller;

  @override
  State<_LiveMatchPageView> createState() => _LiveMatchPageViewState();
}

class _LiveMatchPageViewState extends State<_LiveMatchPageView> {
  static const Color _accent = Color(0xFFC3F400);
  static const Color _inactive = Color(0xFF3A3A3A);

  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: widget.viewportFraction);
  }

  @override
  void didUpdateWidget(covariant _LiveMatchPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportFraction != widget.viewportFraction) {
      _pageController.dispose();
      _pageController = PageController(
        viewportFraction: widget.viewportFraction,
      );
      _currentPage = _currentPage.clamp(0, widget.matches.length - 1);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.matches;
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: matches.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final m = matches[index];
              final id = m.id;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Obx(() {
                  final bumpAt =
                      id == null ? null : widget.controller.scoreBumpAt[id];
                  return LiveMatchCard(
                    // 정렬 변경 시에도 동일 매치의 State가 재사용되도록 매치 id 키 사용.
                    key: ValueKey<Object>(id ?? 'match-$index'),
                    match: m,
                    width: widget.cardWidth,
                    scoreBumpAt: bumpAt,
                    // 추후 detail_url 외부 오픈 자리 — 현재는 no-op.
                    onTap: () {},
                  );
                }),
              );
            },
          ),
        ),
        if (matches.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(matches.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _accent : _inactive,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Realtime 채널 연결 상태 인디케이터.
///
/// - connected=true  : 라임 그린 도트가 호흡하듯 깜빡 (실시간 수신 중)
/// - connected=false : 회색 도트 (폴링/오프라인 상태)
class _RealtimeStatusDot extends StatefulWidget {
  const _RealtimeStatusDot({required this.connected});

  final bool connected;

  @override
  State<_RealtimeStatusDot> createState() => _RealtimeStatusDotState();
}

class _RealtimeStatusDotState extends State<_RealtimeStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _muted = Color(0xFF6B6B6B);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.connected) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RealtimeStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.connected && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.connected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = connected ? _ctrl.value : 0.0;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: connected ? _accent : _muted,
                shape: BoxShape.circle,
                boxShadow:
                    connected
                        ? [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.35 + 0.35 * t),
                            blurRadius: 6 + 6 * t,
                            spreadRadius: 0.5 + 1.5 * t,
                          ),
                        ]
                        : null,
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          connected ? 'LIVE' : 'OFF',
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.8,
            color: connected ? _accent : _muted,
          ),
        ),
      ],
    );
  }
}
