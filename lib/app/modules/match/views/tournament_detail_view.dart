import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/tournament_detail_response.dart';
import '../../../data/models/tournament_match_response.dart';
import '../../../routes/app_routes.dart';
import '../controllers/tournament_participants_controller.dart';
import '../controllers/tournament_detail_controller.dart';

/// 대회 상세 화면 — 날짜 탭 기반(요약 + 일자별 결과 + PODIUM).
///
/// 상단 슬림 헤더(대회명/등급/기간) 아래 가로 칩 탭을 두고, 선택 탭에 따라
/// 본문이 바뀐다:
///   - `요약` : 진행 상태 배너 + 대회 정보 + 외부 링크
///   - 날짜  : 그 날짜 경기를 라운드별로 그룹핑한 결과 리스트
///   - `PODIUM` : 결승에서 도출한 종목별 우승/준우승
class TournamentDetailView extends GetView<TournamentDetailController> {
  const TournamentDetailView({super.key});

  // 매거진 디자인 토큰 (MatchView와 정합)
  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _subtleText = Color(0xFF9CA3A1);
  static const Color _liveRed = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() => _buildHeader(scheme)),
            Obx(() => _buildTabChips(scheme)),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(child: Obx(() => _buildTabBody(scheme))),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.dark.surface,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back<void>(),
      ),
      title: Text(
        'Kinetic Court',
        style: TextStyle(
          color: _accent,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 18.sp,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── Header (슬림) ──────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme scheme) {
    final name = controller.name ?? '대회명 미정';
    final tourLevel = (controller.tourLevel ?? '').trim();
    final logoUrl = controller.logoUrl ?? controller.catLogoUrl;
    final dateLabel = _resolveDateLabel();
    final location = _composeLocation(
      (controller.country ?? '').trim(),
      (controller.location ?? '').trim(),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(logoUrl, scheme),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tourLevel.isNotEmpty)
                  Text(
                    _prettyTourLevel(tourLevel),
                    style: AppTypography.labelLg.copyWith(
                      color: _accent,
                      fontSize: 11.sp,
                      letterSpacing: 1.2,
                    ),
                  ),
                SizedBox(height: 4.h),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMd.copyWith(
                    color: Colors.white,
                    fontSize: 19.sp,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    _buildFlag(controller.flagUrl),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        _composeHeaderMeta(location, dateLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd.copyWith(
                          color: _subtleText,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _composeHeaderMeta(String location, String dateLabel) {
    final parts = <String>[];
    if (location.isNotEmpty && location != '장소 미정') parts.add(location);
    if (dateLabel.isNotEmpty) parts.add(dateLabel);
    return parts.isEmpty ? '정보 미정' : parts.join('  ·  ');
  }

  // ── Tab Chips ─────────────────────────────────────────────────────────

  /// 라운드 데이터가 비어 있을 때 노출할 고정 라운드 칩 라벨.
  /// 대진이 확정되기 전에도 사용자에게 진행 흐름(R32→Final)을 미리 보여준다.
  static const List<String> _placeholderRoundTitles = <String>[
    'R32',
    'R16',
    'QF',
    'SF',
    'Final',
  ];

  Widget _buildTabChips(ColorScheme scheme) {
    final rounds = controller.matchRounds;
    final hasPodium = controller.hasPodium;
    final selected = controller.selectedTabIndex;
    final useFixedRounds = rounds.isEmpty;

    // 칩 디스크립터 구성: [요약] [라운드...] [PODIUM?]
    final chips = <Widget>[];
    var index = 0;

    // 요약
    chips.add(_TabChip(
      kind: _TabChipKind.summary,
      title: '요약',
      selected: selected == index,
      onTap: () => controller.changeTab(0),
    ));

    // 라운드 — 실제 데이터가 있으면 그대로, 없으면 고정 라벨로 미리보기
    if (useFixedRounds) {
      for (final title in _placeholderRoundTitles) {
        index += 1;
        final i = index;
        chips.add(_TabChip(
          kind: _TabChipKind.round,
          title: title,
          selected: selected == i,
          onTap: () => controller.changeTab(i),
        ));
      }
    } else {
      for (final r in rounds) {
        index += 1;
        final i = index;
        chips.add(_TabChip(
          kind: _TabChipKind.round,
          title: _shortRound(r.name),
          selected: selected == i,
          onTap: () => controller.changeTab(i),
        ));
      }
    }

    // PODIUM
    if (hasPodium) {
      index += 1;
      final i = index;
      chips.add(_TabChip(
        kind: _TabChipKind.podium,
        title: 'PODIUM',
        selected: selected == i,
        onTap: () => controller.changeTab(i),
      ));
    }

    return SizedBox(
      height: 64.h,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, i) => chips[i],
            ),
          ),
          if (controller.isMatchesLoading && !controller.hasMatches)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: SizedBox(
                width: 18.w,
                height: 18.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Tab Body ──────────────────────────────────────────────────────────

  Widget _buildTabBody(ColorScheme scheme) {
    final rounds = controller.matchRounds;
    final hasPodium = controller.hasPodium;
    final total = 1 + rounds.length + (hasPodium ? 1 : 0);

    var index = controller.selectedTabIndex;
    if (index >= total) index = 0; // 데이터 변동으로 범위 초과 시 요약으로

    if (index == 0) return _buildSummaryTab(scheme);

    final roundIdx = index - 1;
    if (roundIdx >= 0 && roundIdx < rounds.length) {
      return _buildRoundTab(scheme, rounds[roundIdx]);
    }

    return _buildPodiumTab(scheme);
  }

  // 요약 탭
  Widget _buildSummaryTab(ColorScheme scheme) {
    return ListView(
      padding: EdgeInsets.only(bottom: 40.h),
      children: [
        _buildStatusBanner(scheme),
        if (controller.errorMessage != null) _buildErrorBanner(scheme),
        _buildInfoSection(scheme),
        _buildExternalLink(scheme),
      ],
    );
  }

  // 라운드 탭 — 해당 라운드 경기를 리스트로 노출
  Widget _buildRoundTab(ColorScheme scheme, TournamentMatchRound round) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 40.h),
      children: [
        _buildRoundHeader(round.name, round.matches.length, scheme),
        SizedBox(height: 12.h),
        for (final m in round.matches) ...[
          _MatchCard(match: m),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }

  // PODIUM 탭
  Widget _buildPodiumTab(ColorScheme scheme) {
    final entries = controller.podium;
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 40.h),
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: _accent, size: 22.sp),
            SizedBox(width: 8.w),
            Text(
              'CHAMPIONS',
              style: AppTypography.headlineMd.copyWith(
                color: Colors.white,
                fontSize: 16.sp,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        for (final e in entries) ...[
          _PodiumCard(entry: e),
          SizedBox(height: 12.h),
        ],
      ],
    );
  }

  Widget _buildRoundHeader(String name, int count, ColorScheme scheme) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 18.h,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          name,
          style: AppTypography.headlineMd.copyWith(
            color: Colors.white,
            fontSize: 16.sp,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '$count',
          style: AppTypography.labelLg.copyWith(
            color: _subtleText,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  // ── Status Banner (경기 전 / 중 / 완료) — 요약 탭 ────────────────────

  Widget _buildStatusBanner(ColorScheme scheme) {
    switch (controller.phase) {
      case TournamentPhase.before:
        return _buildBeforeBanner(scheme);
      case TournamentPhase.live:
        return _buildLiveBanner(scheme);
      case TournamentPhase.completed:
        return _buildCompletedBanner(scheme);
    }
  }

  Widget _buildBeforeBanner(ColorScheme scheme) {
    final days = controller.daysUntilStart;
    final dateLine = _resolveDateLabel();
    final String headline;
    final String sub;
    if (days != null && days == 0) {
      headline = '오늘 개막';
      sub = dateLine.isNotEmpty ? dateLine : '오늘 대회가 시작됩니다.';
    } else if (days != null) {
      headline = '개막까지 D-$days';
      sub = dateLine.isNotEmpty ? dateLine : '곧 대회가 시작됩니다.';
    } else {
      headline = '대회 개막 예정';
      sub = dateLine.isNotEmpty ? dateLine : '일정이 확정되면 안내됩니다.';
    }

    return _StatusCard(
      accent: _accent,
      onAccent: _accentDark,
      overline: 'UPCOMING',
      overlineColor: _accentDark,
      overlineBg: _accent,
      icon: Icons.event_available_outlined,
      iconColor: _accent,
      headline: headline,
      subtitle: sub,
      ctaLabel: '대진표 보기',
      onCta: controller.tournamentId != null ? _openParticipants : null,
    );
  }

  /// 참가 선수(대진표) 화면으로 진입 — `Routes.MATCH_PARTICIPANTS`.
  ///
  /// `tournament_id`가 없으면 호출되지 않도록 CTA에서 null 가드한다.
  void _openParticipants() {
    final id = controller.tournamentId;
    if (id == null) return;
    final name = controller.fallback?.name ?? controller.detail?.name;
    Get.toNamed<void>(
      Routes.MATCH_PARTICIPANTS,
      arguments: <String, dynamic>{
        TournamentParticipantsController.argTournamentId: id,
        TournamentParticipantsController.argTournamentName: name,
      },
    );
  }

  Widget _buildLiveBanner(ColorScheme scheme) {
    final dateLine = _resolveDateLabel();
    return _StatusCard(
      accent: _liveRed,
      onAccent: Colors.white,
      overline: 'LIVE NOW',
      overlineColor: Colors.white,
      overlineBg: _liveRed,
      showPulse: true,
      icon: Icons.sports_tennis,
      iconColor: _liveRed,
      headline: '경기 진행 중',
      subtitle: controller.hasLiveScores
          ? '실시간 스코어를 확인하세요.'
          : (dateLine.isNotEmpty ? dateLine : '대회가 진행 중입니다.'),
      ctaLabel: '실시간 스코어 보기',
      onCta: _hasDetailUrl ? controller.openExternalDetail : null,
    );
  }

  Widget _buildCompletedBanner(ColorScheme scheme) {
    final dateLine = _resolveDateLabel();
    return _StatusCard(
      accent: scheme.surfaceContainerHighest,
      onAccent: Colors.white,
      overline: 'COMPLETED',
      overlineColor: _subtleText,
      overlineBg: scheme.surfaceContainerHighest,
      icon: Icons.emoji_events,
      iconColor: _accent,
      headline: '대회 종료',
      subtitle: dateLine.isNotEmpty ? dateLine : '대회가 종료되었습니다.',
      ctaLabel: '최종 결과 보기',
      onCta: _hasDetailUrl ? controller.openExternalDetail : null,
    );
  }

  // ── Info Section — 요약 탭 ────────────────────────────────────────────

  Widget _buildInfoSection(ColorScheme scheme) {
    final rows = <Widget>[];

    final period = _resolveDateLabel();
    if (period.isNotEmpty) {
      rows.add(_InfoRow(label: '기간', value: period));
    }
    final location = _composeLocation(
      (controller.country ?? '').trim(),
      (controller.location ?? '').trim(),
    );
    if (location != '장소 미정') {
      rows.add(_InfoRow(label: '장소', value: location));
    }
    final tourLevel = (controller.tourLevel ?? '').trim();
    if (tourLevel.isNotEmpty) {
      rows.add(_InfoRow(label: '등급', value: _prettyTourLevel(tourLevel)));
    }
    final prize = _formatPrize(controller.prizeMoneyUsd);
    if (prize.isNotEmpty) {
      rows.add(_InfoRow(label: '총 상금', value: prize));
    }
    final year = controller.detail?.year;
    if (year != null) {
      rows.add(_InfoRow(label: '시즌', value: '$year'));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: '대회 정보',
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i != rows.length - 1)
                Divider(height: 1, color: scheme.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }

  // ── External link — 요약 탭 ───────────────────────────────────────────

  Widget _buildExternalLink(ColorScheme scheme) {
    if (!_hasDetailUrl) return const SizedBox.shrink();
    final url = controller.detailUrl!.trim();
    return _Section(
      title: 'More',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.openExternalDetail,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ListTile(
              leading: const Icon(Icons.open_in_new, color: _accent),
              title: Text(
                'BWF 공식 대회 페이지',
                style: AppTypography.bodyMd.copyWith(color: Colors.white),
              ),
              subtitle: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd.copyWith(
                  color: _subtleText,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme scheme) {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: _subtleText, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              controller.errorMessage ?? '',
              style: AppTypography.bodyMd.copyWith(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: controller.refreshAll,
            child: const Text(
              '재시도',
              style: TextStyle(
                color: _accent,
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── shared visuals ────────────────────────────────────────────────────

  Widget _buildLogo(String? url, ColorScheme scheme) {
    final double size = 64.w;
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.emoji_events_outlined,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          size: 28.sp,
        ),
      );
    }
    // 대회 로고는 투명 배경 PNG가 많아 밝은 타일 위에 contain으로 표시한다.
    // (match_view와 동일하게 CachedNetworkImage 대신 Image.network 사용)
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
      ),
      padding: EdgeInsets.all(8.w),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 18.w,
              height: 18.h,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stack) {
          debugPrint('TournamentDetailView._buildLogo error: url=$url e=$error');
          return Center(
            child: Icon(
              Icons.emoji_events_outlined,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 28.sp,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlag(String? url) {
    if (url == null || url.isEmpty) {
      return SizedBox(width: 20.w, height: 13.h);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(2.r),
      child: Image.network(
        url,
        width: 20.w,
        height: 13.h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            SizedBox(width: 20.w, height: 13.h),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────

  bool get _hasDetailUrl {
    final u = controller.detailUrl;
    return u != null && u.trim().isNotEmpty;
  }

  String _resolveDateLabel() {
    final label = (controller.dateLabel ?? '').trim();
    if (label.isNotEmpty) return label;
    final s = controller.startDate;
    final e = controller.endDate;
    if (s != null && e != null) return '$s ~ $e';
    if (s != null) return s;
    if (e != null) return e;
    return '';
  }

  String _composeLocation(String country, String location) {
    if (country.isEmpty && location.isEmpty) return '장소 미정';
    if (country.isEmpty) return location;
    if (location.isEmpty) return country;
    return '$country · $location';
  }

  /// 라운드명을 칩에 맞게 짧게 변환.
  /// 예: "Quarter Finals" → "QF", "Semi Finals" → "SF", "Round of 16" → "R16".
  String _shortRound(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return '기타';
    final lower = r.toLowerCase();

    // "Round of 16" / "R16" / "1/16" 등에서 숫자 추출
    final roundOf = RegExp(r'(?:round of|1/)\s*(\d+)').firstMatch(lower);
    if (roundOf != null) return 'R${roundOf.group(1)}';

    if (lower.contains('final') &&
        !lower.contains('semi') &&
        !lower.contains('quarter')) {
      return 'Final';
    }
    if (lower.contains('semi')) return 'SF';
    if (lower.contains('quarter')) return 'QF';
    if (lower.contains('qualif')) return '예선';

    // 그 외엔 원본을 짧게 (너무 길면 앞부분만)
    return r.length <= 12 ? r : '${r.substring(0, 11)}…';
  }

  /// SUPER_1000 → "Super 1000" 처럼 보기 좋게 변환.
  String _prettyTourLevel(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _formatPrize(double? usd) {
    if (usd == null || usd <= 0) return '';
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

/// 탭 칩 종류
enum _TabChipKind { summary, round, podium }

/// 가로 탭 칩 — 요약 / 라운드 / PODIUM(빨강)
class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.kind,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final _TabChipKind kind;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _liveRed = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    final isPodium = kind == _TabChipKind.podium;

    // 배경/테두리/텍스트 색 결정
    final Color bg;
    final Color border;
    final Color fg;
    if (isPodium) {
      bg = selected ? _liveRed : _liveRed.withValues(alpha: 0.85);
      border = _liveRed;
      fg = Colors.white;
    } else if (selected) {
      bg = _accent;
      border = _accent;
      fg = _accentDark;
    } else {
      bg = scheme.surfaceContainer;
      border = scheme.outlineVariant;
      fg = Colors.white;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          constraints: BoxConstraints(minWidth: 52.w),
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border),
          ),
          child: Center(child: _buildContent(fg)),
        ),
      ),
    );
  }

  Widget _buildContent(Color fg) {
    return Text(
      title,
      style: AppTypography.labelLg.copyWith(
        color: fg,
        fontSize: 13.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: kind == _TabChipKind.podium ? 0.8 : 0.4,
      ),
    );
  }
}

/// PODIUM 카드 — 종목별 우승/준우승
class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry});

  final PodiumEntry entry;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    final champCtry = (entry.championCountry ?? '').trim();
    final runner = (entry.runnerUp ?? '').trim();
    final runnerCtry = (entry.runnerUpCountry ?? '').trim();
    final score = (entry.score ?? '').trim();
    final champPts = entry.championPoints;
    final runnerPts = entry.runnerUpPoints;
    final hasGames = champPts.isNotEmpty && champPts.length == runnerPts.length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.eventName.toUpperCase(),
            style: AppTypography.labelLg.copyWith(
              color: _accent,
              fontSize: 11.sp,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 12.h),
          // 우승
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: _accent, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  entry.champion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.sp,
                  ),
                ),
              ),
              if (champCtry.isNotEmpty) ...[
                SizedBox(width: 8.w),
                Text(
                  champCtry.toUpperCase(),
                  style: AppTypography.labelLg.copyWith(
                    color: _subtleText,
                    fontSize: 11.sp,
                  ),
                ),
              ],
              if (hasGames)
                for (var i = 0; i < champPts.length; i++)
                  _GameCell(
                    point: champPts[i],
                    won: champPts[i] > runnerPts[i],
                  ),
            ],
          ),
          if (runner.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 28.w),
                Expanded(
                  child: Text(
                    runner,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(
                      color: _subtleText,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                if (runnerCtry.isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  Text(
                    runnerCtry.toUpperCase(),
                    style: AppTypography.labelLg.copyWith(
                      color: _subtleText,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
                if (hasGames)
                  for (var i = 0; i < runnerPts.length; i++)
                    _GameCell(
                      point: runnerPts[i],
                      won: runnerPts[i] > champPts[i],
                    ),
              ],
            ),
          ],
          // 게임 파싱 실패 시 원본 스코어 문자열 폴백
          if (!hasGames && score.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Divider(height: 1, color: scheme.outlineVariant),
            SizedBox(height: 10.h),
            Row(
              children: [
                Text(
                  'SCORE',
                  style: AppTypography.labelLg.copyWith(
                    color: _subtleText,
                    fontSize: 10.sp,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    score,
                    style: AppTypography.statsNumber.copyWith(
                      color: Colors.white,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 진행 단계별 상태 카드 (오버라인 뱃지 + 헤드라인 + 부제 + CTA)
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.accent,
    required this.onAccent,
    required this.overline,
    required this.overlineColor,
    required this.overlineBg,
    required this.icon,
    required this.iconColor,
    required this.headline,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
    this.showPulse = false,
  });

  final Color accent;
  final Color onAccent;
  final String overline;
  final Color overlineColor;
  final Color overlineBg;
  final IconData icon;
  final Color iconColor;
  final String headline;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        padding: EdgeInsets.all(18.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: overlineBg,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showPulse) ...[
                        Container(
                          width: 7.w,
                          height: 7.h,
                          decoration: BoxDecoration(
                            color: overlineColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                      ],
                      Text(
                        overline,
                        style: AppTypography.labelLg.copyWith(
                          color: overlineColor,
                          fontSize: 11.sp,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(icon, color: iconColor, size: 22.sp),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              headline,
              style: AppTypography.headlineLg.copyWith(
                color: Colors.white,
                fontSize: 24.sp,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              style: AppTypography.bodyMd.copyWith(
                color: const Color(0xFF9CA3A1),
              ),
            ),
            if (onCta != null) ...[
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ctaLabel,
                        style: TextStyle(
                          fontFamily: AppTypography.chivo,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.sp,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(Icons.arrow_forward, size: 18.sp),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 대회 정보 행 (라벨 — 값)
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: AppTypography.labelLg.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 12.sp,
                letterSpacing: 0.6,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMd.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// 섹션 래퍼 (타이틀 + 구분선 + 본문)
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: AppTypography.headlineLg.copyWith(color: Colors.white),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(height: 1, color: scheme.outlineVariant),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          child,
        ],
      ),
    );
  }
}

/// 단일 경기 카드 — 양 팀 + 스코어 + 승자 강조
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final TournamentMatchResponse match;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    final winnerSide = match.winnerSide;
    final meta = _composeMeta();
    final games = match.games;
    final scoreText = (match.scoreDisplay ?? '').trim();
    final event = (match.eventName ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (event.isNotEmpty)
                Flexible(
                  child: Text(
                    event,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLg.copyWith(
                      color: _accent,
                      fontSize: 11.sp,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              const Spacer(),
              if (meta.isNotEmpty)
                Text(
                  meta,
                  style: AppTypography.bodyMd.copyWith(
                    color: _subtleText,
                    fontSize: 11.sp,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          _teamLine(
            name: match.team1Display,
            country: match.team1Country,
            seed: match.team1Seed,
            isWinner: winnerSide == 1,
            hasWinner: winnerSide != null,
            points: [for (final g in games) g.team1],
            oppPoints: [for (final g in games) g.team2],
          ),
          SizedBox(height: 10.h),
          _teamLine(
            name: match.team2Display,
            country: match.team2Country,
            seed: match.team2Seed,
            isWinner: winnerSide == 2,
            hasWinner: winnerSide != null,
            points: [for (final g in games) g.team2],
            oppPoints: [for (final g in games) g.team1],
          ),
          // 게임 파싱 실패했지만 원본 스코어 문자열이 있으면 폴백 표기
          if (games.isEmpty && scoreText.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Divider(height: 1, color: scheme.outlineVariant),
            SizedBox(height: 10.h),
            Row(
              children: [
                Text(
                  'SCORE',
                  style: AppTypography.labelLg.copyWith(
                    color: _subtleText,
                    fontSize: 10.sp,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    scoreText,
                    style: AppTypography.statsNumber.copyWith(
                      color: Colors.white,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamLine({
    required String name,
    required String? country,
    required String? seed,
    required bool isWinner,
    required bool hasWinner,
    required List<int> points,
    required List<int> oppPoints,
  }) {
    final color = isWinner
        ? Colors.white
        : (hasWinner ? _subtleText : Colors.white);
    final ctry = (country ?? '').trim();
    final sd = (seed ?? '').trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20.w,
          child: isWinner
              ? Icon(Icons.emoji_events, color: _accent, size: 16.sp)
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: AppTypography.bodyMd.copyWith(
                    color: color,
                    fontWeight:
                        isWinner ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 14.sp,
                  ),
                ),
                if (sd.isNotEmpty)
                  TextSpan(
                    text: '  [$sd]',
                    style: AppTypography.labelLg.copyWith(
                      color: _subtleText,
                      fontSize: 11.sp,
                    ),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (ctry.isNotEmpty) ...[
          SizedBox(width: 8.w),
          Text(
            ctry.toUpperCase(),
            style: AppTypography.labelLg.copyWith(
              color: _subtleText,
              fontSize: 11.sp,
              letterSpacing: 0.5,
            ),
          ),
        ],
        // 게임별 점수 컬럼 (양 팀 행에서 동일 폭으로 정렬)
        for (var i = 0; i < points.length; i++)
          _GameCell(
            point: points[i],
            won: points[i] > oppPoints[i],
          ),
      ],
    );
  }

  String _composeMeta() {
    final parts = <String>[];
    final dt = match.matchDateTime;
    if (dt != null) {
      final local = dt.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mi = local.minute.toString().padLeft(2, '0');
      parts.add('$hh:$mi');
    }
    final court = (match.courtName ?? '').trim();
    if (court.isNotEmpty) parts.add(court);
    return parts.join(' · ');
  }
}

/// 게임 단위 점수 셀 — 양 팀 행에서 같은 폭으로 정렬되는 숫자 칸.
/// 해당 게임을 이긴 쪽은 액센트로 강조한다.
class _GameCell extends StatelessWidget {
  const _GameCell({required this.point, required this.won});

  final int point;
  final bool won;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26.w,
      alignment: Alignment.center,
      margin: EdgeInsets.only(left: 6.w),
      child: Text(
        '$point',
        style: AppTypography.statsNumber.copyWith(
          fontSize: 17.sp,
          color: won ? _accent : _subtleText,
        ),
      ),
    );
  }
}
