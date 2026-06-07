import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/today_match_response.dart';

/// 오늘 경기 단일 카드 (가로 캐러셀용).
///
/// 대회 상세 화면(`TournamentDetailView._MatchCard`)와 동일한 디자인 패턴.
/// 좌상단 종목 라벨(라임) · 우상단 "HH:mm · Court N" 메타 · 양 팀 라인
/// (트로피 + 선수명/시드 + 국가코드) · 게임별 점수 셀.
class TodayMatchCard extends StatelessWidget {
  const TodayMatchCard({
    super.key,
    required this.match,
    this.onTap,
  });

  final TodayMatchResponse match;
  final VoidCallback? onTap;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF0E0E0E);
  static const Color _subtleText = Color(0xFF9CA3A1);

  static const double _cardWidth = 310;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    final winnerSide = match.winnerSide;
    final meta = _composeMeta();
    final games = match.games;
    final event = (match.eventName ?? '').trim();
    final showStatusBadge = match.isWalkover || match.isRetired;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: _cardWidth,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
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
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (showStatusBadge) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        match.isWalkover ? 'W/O' : 'RET',
                        style: const TextStyle(
                          fontFamily: AppTypography.chivo,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          color: _accentDark,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: AppTypography.bodyMd.copyWith(
                        color: _subtleText,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _teamLine(
                name: match.team1Display,
                country: match.team1Country,
                seed: match.team1Seed,
                isWinner: winnerSide == 1,
                hasWinner: winnerSide != null,
                points: [for (final g in games) g.team1],
                oppPoints: [for (final g in games) g.team2],
              ),
              const SizedBox(height: 10),
              _teamLine(
                name: match.team2Display,
                country: match.team2Country,
                seed: match.team2Seed,
                isWinner: winnerSide == 2,
                hasWinner: winnerSide != null,
                points: [for (final g in games) g.team2],
                oppPoints: [for (final g in games) g.team1],
              ),
            ],
          ),
        ),
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
          width: 20,
          child: isWinner
              ? const Icon(Icons.emoji_events, color: _accent, size: 16)
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
                    fontSize: 14,
                  ),
                ),
                if (sd.isNotEmpty)
                  TextSpan(
                    text: '  [$sd]',
                    style: AppTypography.labelLg.copyWith(
                      color: _subtleText,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (ctry.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            ctry.toUpperCase(),
            style: AppTypography.labelLg.copyWith(
              color: _subtleText,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
    final t = match.displayKoreanTime?.trim();
    if (t != null && t.isNotEmpty) parts.add(t);
    final c = match.courtName?.trim();
    if (c != null && c.isNotEmpty) parts.add(c);
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
      width: 26,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(left: 6),
      child: Text(
        '$point',
        style: AppTypography.statsNumber.copyWith(
          fontSize: 17,
          color: won ? _accent : _subtleText,
        ),
      ),
    );
  }
}
