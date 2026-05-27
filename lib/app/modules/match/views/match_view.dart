import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/tournament_response.dart';
import '../controllers/match_controller.dart';

/// 경기(국제 대회) 화면 — Stitch: 국제 대회 리스트 (매거진)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : 225c4429594e4cb3835b154cbc861919
class MatchView extends GetView<MatchController> {
  const MatchView({super.key});

  // Stitch 디자인 토큰 (AppColors와 정합되지 않는 시안 디테일만 별도 상수로 보존)
  static const Color _accent = Color(0xFFC3F400); // primaryContainer
  static const Color _accentDark = Color(0xFF283500); // onPrimary on accent
  static const Color _badgeBg = Color(0xFF201F1F); // surfaceContainer 톤
  static const Color _subtleText = Color(0xFF9CA3A1);
  static const Color _divider = Color(0xFF1F2421);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshTournaments,
          color: _accent,
          backgroundColor: scheme.surfaceContainer,
          child: _buildContent(scheme),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.dark.surface,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Kinetic Court',
        style: TextStyle(
          color: _accent,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
      ),
      leading: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Icon(Icons.menu, color: Colors.white),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.search, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    // 정적 위젯 + 동적 영역(Obx)으로 분리하여 GetX 경고 회피
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildYearSelector()),
        SliverToBoxAdapter(child: const SizedBox(height: 16)),
        SliverToBoxAdapter(child: _buildStateArea(scheme)),
      ],
    );
  }

  /// 상단 헤더 ("World Tour Calendar" + 부제)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'World Tour Calendar',
            style: AppTypography.headlineLg.copyWith(
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'BWF가 공인하는 국제 대회 일정을 한눈에 확인하세요.',
            style: AppTypography.bodyMd.copyWith(
              color: _subtleText,
            ),
          ),
        ],
      ),
    );
  }

  /// 연도 선택 컨트롤 (이전/다음 화살표 + 현재 연도 라벨)
  Widget _buildYearSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _badgeBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _divider),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // 이전 연도 버튼
            Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.goPreviousYear,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            // 현재 연도
            Expanded(
              child: Center(
                child: Obx(
                  () => Text(
                    '${controller.selectedYear} Season',
                    style: AppTypography.labelLg.copyWith(
                      color: _accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
            // 다음 연도 버튼
            Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.goNextYear,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상태 분기 영역 (로딩 / 에러 / 빈 / 정상 목록)
  Widget _buildStateArea(ColorScheme scheme) {
    return Obx(() {
      if (controller.isLoading && controller.tournaments.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: CircularProgressIndicator(color: _accent),
          ),
        );
      }

      final error = controller.errorMessage;
      if (error != null && controller.tournaments.isEmpty) {
        return _buildErrorState(error);
      }

      if (controller.tournaments.isEmpty) {
        return _buildEmptyState();
      }

      return _buildTournamentList(controller.tournaments);
    });
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: _subtleText),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: controller.refreshTournaments,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _accentDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
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
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: _subtleText,
          ),
          const SizedBox(height: 12),
          Obx(() => Text(
                '${controller.selectedYear}년에는 등록된 대회가 없습니다.',
                style: AppTypography.bodyMd.copyWith(color: Colors.white),
              )),
          const SizedBox(height: 6),
          Text(
            '다른 연도를 선택해보세요.',
            style: AppTypography.bodyMd.copyWith(color: _subtleText),
          ),
        ],
      ),
    );
  }

  /// 대회 카드 리스트 — 월별 그룹 헤더 + 카드들
  Widget _buildTournamentList(List<TournamentResponse> tournaments) {
    final groups = _groupByMonth(tournaments);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in groups) ...[
            _buildMonthHeader(group.label),
            const SizedBox(height: 12),
            for (final t in group.items) ...[
              _TournamentCard(
                tournament: t,
                onTap: () => controller.openTournamentDetail(t),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.headlineMd.copyWith(
            color: Colors.white,
            fontSize: 20,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  /// 대회 목록을 시작월(YYYY-MM) 기준으로 그룹핑한다.
  List<_MonthGroup> _groupByMonth(List<TournamentResponse> list) {
    final Map<String, List<TournamentResponse>> map = {};
    for (final t in list) {
      final start = t.startDate;
      final key = (start != null && start.length >= 7)
          ? start.substring(0, 7) // YYYY-MM
          : '9999-99';
      map.putIfAbsent(key, () => <TournamentResponse>[]).add(t);
    }

    final keys = map.keys.toList()..sort();
    return [
      for (final k in keys)
        _MonthGroup(
          key: k,
          label: _labelFromGroup(k, map[k]!),
          items: map[k]!,
        ),
    ];
  }

  String _labelFromGroup(String key, List<TournamentResponse> items) {
    if (key == '9999-99') return '일정 미정';
    final first = items.first;
    final start = first.startDate;
    if (start == null || start.length < 7) return key;
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthInt = int.tryParse(start.substring(5, 7));
    final yearStr = start.substring(0, 4);
    if (monthInt == null || monthInt < 1 || monthInt > 12) return key;
    return '${monthNames[monthInt - 1]} $yearStr';
  }
}

/// 월 단위 그룹 (정렬용 key + 표시용 label + 항목들)
class _MonthGroup {
  _MonthGroup({required this.key, required this.label, required this.items});

  final String key;
  final String label;
  final List<TournamentResponse> items;
}

/// 대회 단일 카드 (매거진 스타일)
class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament, required this.onTap});

  final TournamentResponse tournament;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _cardBg = Color(0xFF1C1B1B);
  static const Color _cardBorder = Color(0xFF2A2A2A);
  static const Color _subtleText = Color(0xFF9CA3A1);
  static const Color _liveRed = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final isLive = t.hasLiveScores == true;
    final tourLevel = (t.tourLevel ?? '').trim();
    final country = (t.country ?? '').trim();
    final name = (t.name ?? '대회명 미정').trim();
    final dateLabel = _resolveDateLabel(t);
    final location = (t.location ?? '').trim();
    final status = (t.status ?? '').trim();
    final prize = _formatPrize(t.prizeMoneyUsd);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 좌측 본문
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1행: tour_level 뱃지 + LIVE 뱃지
                    Row(
                      children: [
                        if (tourLevel.isNotEmpty)
                          _buildTourLevelBadge(tourLevel),
                        if (isLive) ...[
                          if (tourLevel.isNotEmpty) const SizedBox(width: 6),
                          _buildLiveBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 2행: 대회명
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 3행: 국기 + 국가/도시
                    Row(
                      children: [
                        _buildFlag(t.flagUrl),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _composeLocation(country, location),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMd.copyWith(
                              color: _subtleText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 4행: 날짜 라벨
                    if (dateLabel.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                            color: _subtleText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: AppTypography.bodyMd.copyWith(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    // 5행: 상금 + 상태
                    if (prize.isNotEmpty || status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (prize.isNotEmpty) ...[
                            const Icon(
                              Icons.emoji_events_outlined,
                              size: 14,
                              color: _accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              prize,
                              style: AppTypography.labelLg.copyWith(
                                color: _accent,
                                fontSize: 12,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                          if (prize.isNotEmpty && status.isNotEmpty)
                            const SizedBox(width: 12),
                          if (status.isNotEmpty) _buildStatusBadge(status),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 우측 로고 / 화살표
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLogo(t.logoUrl ?? t.catLogoUrl),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTourLevelBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTypography.labelLg.copyWith(
          color: _accentDark,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _liveRed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF201F1F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardBorder),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTypography.labelLg.copyWith(
          color: _subtleText,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFlag(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 18,
        height: 12,
        decoration: BoxDecoration(
          color: _cardBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 18,
        height: 12,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: 18,
          height: 12,
          color: _cardBorder,
        ),
        errorWidget: (context, _, __) => Container(
          width: 18,
          height: 12,
          color: _cardBorder,
        ),
      ),
    );
  }

  Widget _buildLogo(String? url) {
    const double size = 56;
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _cardBorder,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.sports_tennis,
          color: _subtleText,
          size: 24,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: size,
          height: size,
          color: _cardBorder,
        ),
        errorWidget: (context, _, __) => Container(
          width: size,
          height: size,
          color: _cardBorder,
          alignment: Alignment.center,
          child: const Icon(
            Icons.sports_tennis,
            color: _subtleText,
            size: 24,
          ),
        ),
      ),
    );
  }

  String _composeLocation(String country, String location) {
    if (country.isEmpty && location.isEmpty) return '장소 미정';
    if (country.isEmpty) return location;
    if (location.isEmpty) return country;
    return '$country · $location';
  }

  String _resolveDateLabel(TournamentResponse t) {
    final label = (t.dateLabel ?? '').trim();
    if (label.isNotEmpty) return label;
    final s = t.startDate;
    final e = t.endDate;
    if (s != null && e != null) return '$s ~ $e';
    if (s != null) return s;
    if (e != null) return e;
    return '';
  }

  String _formatPrize(double? usd) {
    if (usd == null || usd <= 0) return '';
    // 정수부 천 단위 콤마 + $ 접두 (소수점은 표기 생략)
    final s = usd.truncate().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buf.write(',');
      }
    }
    return '\$${buf.toString()}';
  }
}
