import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../theme/app_typography.dart';
import '../../../../data/models/live_match_response.dart';
import '../../../../utils/country_flag.dart';

/// 라이브 매치 단일 카드 (홈 화면 상단 캐러셀에서 사용).
///
/// 매거진 디자인 토큰(검정 카드 + 라임 옐로우 액센트)을 따른다.
/// - 헤더: 대회 로고 + 대회명 + 종목/라운드/코트 라벨, 우측 상단 LIVE 배지
/// - 본문: team1 vs team2 (국기/시드/선수명) + 게임 스코어
/// - 푸터: 코트명 (있을 경우)
///
/// 카드 폭은 캐러셀에서 외부에서 결정(보통 화면 폭의 약 85%).
/// [onTap]은 현재는 placeholder — 추후 detail_url 외부 오픈에 사용.
class LiveMatchCard extends StatelessWidget {
  const LiveMatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.width = 320,
  });

  final LiveMatchResponse match;
  final VoidCallback? onTap;
  final double width;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _cardBg = Color(0xFF1C1B1B);
  static const Color _cardBorder = Color(0xFF2A2A2A);
  static const Color _subtleText = Color(0xFF9CA3A1);
  static const Color _liveRed = Color(0xFFFF4D4F);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildEventLine(),
                const SizedBox(height: 10),
                _buildTeamRow(
                  side: 1,
                  display: match.team1Display,
                  country: (match.team1Country ?? '').trim(),
                  seed: (match.team1Seed ?? '').trim(),
                ),
                const SizedBox(height: 8),
                _buildScoreLine(),
                const SizedBox(height: 8),
                _buildTeamRow(
                  side: 2,
                  display: match.team2Display,
                  country: (match.team2Country ?? '').trim(),
                  seed: (match.team2Seed ?? '').trim(),
                ),
                if ((match.courtName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildCourtFooter(match.courtName!.trim()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 헤더 (로고 + 대회명 + LIVE 배지) ─────────────────────────
  Widget _buildHeader() {
    final logo = match.displayLogoUrl;
    final tournamentName = (match.name ?? '').trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLogo(logo),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tournamentName.isEmpty ? '대회 정보 없음' : tournamentName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              color: Colors.white,
              fontSize: 12,
              height: 1.25,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildLiveBadge(),
      ],
    );
  }

  Widget _buildLogo(String? url) {
    const double size = 28;
    if (url == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.emoji_events_outlined,
          size: 16,
          color: _subtleText,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: const Color(0xFF2A2A2A),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF2A2A2A),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 14,
            color: _subtleText,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _liveRed.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _liveRed.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _liveRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.0,
              color: _liveRed,
            ),
          ),
        ],
      ),
    );
  }

  // ── 종목·라운드 라인 ──────────────────────────────────────
  Widget _buildEventLine() {
    final parts = <String>[];
    final ev = (match.eventName ?? '').trim();
    if (ev.isNotEmpty) parts.add(ev);
    final round = (match.roundName ?? '').trim();
    if (round.isNotEmpty) parts.add(round);
    final category = (match.categoryName ?? '').trim();
    if (category.isNotEmpty && parts.length < 2) parts.add(category);

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: AppTypography.chivo,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.4,
        color: _accent,
      ),
    );
  }

  // ── 팀 row (국기/시드/이름) ──────────────────────────────────
  Widget _buildTeamRow({
    required int side,
    required String display,
    required String country,
    required String seed,
  }) {
    final flag = flagEmoji(country);
    final isWinner = match.winnerSide == side;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            flag.isEmpty ? '🏳' : flag,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(width: 6),
        if (seed.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _accentDark,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              seed,
              style: const TextStyle(
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.4,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
              height: 1.2,
              color: isWinner ? _accent : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ── 스코어 라인 (게임별 점수 또는 폴백 문자열) ─────────────
  Widget _buildScoreLine() {
    final games = match.games;
    if (games.isNotEmpty) {
      final currentIdx = match.currentGameIndex;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < games.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildGamePill(
              game: games[i],
              isCurrent: i == currentIdx,
            ),
          ],
        ],
      );
    }

    final fallback = (match.scoreDisplay ?? '').trim();
    if (fallback.isEmpty) {
      return Text(
        '경기 시작 대기',
        style: AppTypography.bodyMd.copyWith(
          color: _subtleText,
          fontSize: 12,
        ),
      );
    }
    return Text(
      fallback,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: AppTypography.chivo,
        fontWeight: FontWeight.w800,
        fontSize: 14,
        letterSpacing: 0.4,
        color: Colors.white,
      ),
    );
  }

  Widget _buildGamePill({
    required LiveGameScore game,
    required bool isCurrent,
  }) {
    final bg = isCurrent ? _accent : const Color(0xFF201F1F);
    final border = isCurrent ? _accent : const Color(0xFF2A2A2A);
    final fg = isCurrent ? _accentDark : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        '${game.team1}-${game.team2}',
        style: TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }

  // ── 푸터 (코트명) ────────────────────────────────────────
  Widget _buildCourtFooter(String courtName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.stadium_outlined, size: 12, color: _subtleText),
        const SizedBox(width: 4),
        Text(
          courtName,
          style: const TextStyle(
            fontFamily: AppTypography.sourceSans,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: _subtleText,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
