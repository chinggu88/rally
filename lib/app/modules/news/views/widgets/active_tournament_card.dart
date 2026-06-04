import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_spacing.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/active_tournament_response.dart';

/// "남은 대회"(진행중/진행예정) 간략형 배너 — 홈 화면 최상단 가로 캐러셀에서 사용.
///
/// 한 줄짜리 컴팩트 배너로 표시한다.
/// - 형식: `NEXT: [투어 등급 배지] 대회명`  (진행중이면 `NOW:`)
/// - 한국 선수가 있으면 끝에 🇰🇷 인원 미니 배지 표시 + 탭 시 명단 다이얼로그
class ActiveTournamentCard extends StatelessWidget {
  const ActiveTournamentCard({
    super.key,
    required this.tournament,
    this.onTap,
  });

  final ActiveTournamentResponse tournament;

  /// 커스텀 탭 핸들러. 미지정 시 한국 선수 명단 다이얼로그를 띄운다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    final ongoing = tournament.isOngoing;
    final hasKoreans = tournament.hasKoreans;

    // 한국 선수가 없으면 탭(명단 다이얼로그) 비활성화.
    final tapHandler =
        onTap ?? (hasKoreans ? () => _showKoreanPlayersDialog(context) : null);

    // 진행중(NOW)은 error 액센트로 강조, 예정(NEXT)은 primary(라임) 액센트.
    final prefix = ongoing ? 'NOW' : 'NEXT';
    final accent =
        ongoing ? const Color(0xFFD50000) : scheme.primaryContainer;
    final level = _tourLevelLabel();

    return GestureDetector(
      onTap: tapHandler,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.stackGapSm,
            vertical: AppSpacing.base,
          ),
          decoration: BoxDecoration(
            color: ongoing
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: ongoing
                  ? accent.withValues(alpha: 0.5)
                  : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ongoing)
                // NOW: 빨간 원 배지로 강조
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    prefix,
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                )
              else ...[
                // 상태 닷
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '$prefix:',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: accent,
                  ),
                ),
              ],
              if (level != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    level,
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tournament.name ?? '이름 미정',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.chivo,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (hasKoreans) ...[
                const SizedBox(width: 8),
                _koreanMiniBadge(scheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 투어 등급 라벨 ("SUPER_1000" → "Super 1000"). 매핑 불가 시 null.
  String? _tourLevelLabel() {
    final raw = tournament.tourLevel?.trim();
    if (raw == null || raw.isEmpty) return null;
    final words = raw.split(RegExp(r'[_\s]+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return null;
    return words
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// 한국 선수 인원 미니 배지 (🇰🇷N).
  Widget _koreanMiniBadge(ColorScheme scheme) {
    final count = tournament.koreanPlayerCount ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border:
            Border.all(color: scheme.primaryContainer.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇰🇷', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: AppTypography.labelLg.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 10,
              color: scheme.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// 한국 선수 참여 명단 다이얼로그.
  void _showKoreanPlayersDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => KoreanPlayersDialog(tournament: tournament),
    );
  }
}

/// 대회별 한국 선수 참여 명단 다이얼로그.
class KoreanPlayersDialog extends StatelessWidget {
  const KoreanPlayersDialog({super.key, required this.tournament});

  final ActiveTournamentResponse tournament;

  // 앱 디자인 시스템(AppColors.dark) 토큰.
  static final Color accent = AppColors.dark.primaryContainer;
  static final Color cardBg = AppColors.dark.surfaceContainerLow;
  static final Color rowBg = AppColors.dark.surfaceContainerLowest;
  static final Color cardBorder = AppColors.dark.surfaceContainerHigh;
  static final Color subtleText = AppColors.dark.onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final players = tournament.koreanPlayers
        .where((p) => (p.name?.trim().isNotEmpty ?? false))
        .toList();
    final count = tournament.koreanPlayerCount ?? players.length;

    return Dialog(
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cardBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name ?? '대회',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.chivo,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('🇰🇷', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              '한국 선수 $count명 참가',
                              style: TextStyle(
                                fontFamily: AppTypography.chivo,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: subtleText, size: 22),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cardBorder),
            // 명단
            Flexible(
              child: players.isEmpty
                  ? _emptyBody()
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = players[index];
                        return _playerRow(index + 1, p.name ?? '-');
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerRow(int rank, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          const Text('🇰🇷', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _emptyBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 36, color: subtleText),
          const SizedBox(height: 10),
          const Text(
            '참가 선수 명단 정보가 아직 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '대진이 발표되면 명단이 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: subtleText),
          ),
        ],
      ),
    );
  }
}
