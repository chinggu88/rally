import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_spacing.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/active_tournament_response.dart';
import '../../../../data/models/tournament_match_response.dart';
import '../../../../data/repositories/tournament_repository.dart';

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
        constraints: BoxConstraints(maxWidth: 320.w),
        child: Container(
          padding: EdgeInsets.symmetric(
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
                      EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    prefix,
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.sp,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                )
              else ...[
                // 상태 닷
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                SizedBox(width: 6.w),
                Text(
                  '$prefix:',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.sp,
                    color: accent,
                  ),
                ),
              ],
              if (level != null) ...[
                SizedBox(width: 8.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    level,
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.sp,
                      letterSpacing: 0.2,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  tournament.name ?? '이름 미정',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.chivo,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (hasKoreans) ...[
                SizedBox(width: 8.w),
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
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border:
            Border.all(color: scheme.primaryContainer.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇰🇷', style: TextStyle(fontSize: 10.sp)),
          SizedBox(width: 3.w),
          Text(
            '$count',
            style: AppTypography.labelLg.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 10.sp,
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
class KoreanPlayersDialog extends StatefulWidget {
  const KoreanPlayersDialog({super.key, required this.tournament});

  final ActiveTournamentResponse tournament;

  @override
  State<KoreanPlayersDialog> createState() => _KoreanPlayersDialogState();
}

class _KoreanPlayersDialogState extends State<KoreanPlayersDialog> {
  // 앱 디자인 시스템(AppColors.dark) 토큰.
  static final Color accent = AppColors.dark.primaryContainer;
  static final Color cardBg = AppColors.dark.surfaceContainerLow;
  static final Color rowBg = AppColors.dark.surfaceContainerLowest;
  static final Color cardBorder = AppColors.dark.surfaceContainerHigh;
  static final Color subtleText = AppColors.dark.onSurfaceVariant;

  /// 선수명(trim+lowercase) → (라운드 라벨, 탈락 여부).
  /// null이면 아직 조회 전, 빈 맵이면 조회 완료(라벨 없음).
  Map<String, ({String label, bool eliminated})>? _labels;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final id = widget.tournament.tournamentId;
    if (id == null) {
      setState(() {
        _labels = const <String, ({String label, bool eliminated})>{};
      });
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final repo = Get.find<TournamentRepository>();
      final res = await repo.getTournamentMatches(tournamentId: id);
      final matches = res.matches ?? const <TournamentMatchResponse>[];
      final map = <String, ({String label, bool eliminated})>{};
      for (final p in widget.tournament.koreanPlayers) {
        final name = p.name?.trim();
        if (name == null || name.isEmpty) continue;
        final result = _labelForPlayer(name, matches);
        if (result != null) map[name.toLowerCase()] = result;
      }
      if (!mounted) return;
      setState(() {
        _labels = map;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _labels = const <String, ({String label, bool eliminated})>{};
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.tournament.koreanPlayers
        .where((p) => (p.name?.trim().isNotEmpty ?? false))
        .toList();
    final count = widget.tournament.koreanPlayerCount ?? players.length;

    return Dialog(
      backgroundColor: cardBg,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 40.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
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
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 12.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tournament.name ?? '대회',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.chivo,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.sp,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Text('🇰🇷', style: TextStyle(fontSize: 13.sp)),
                            SizedBox(width: 6.w),
                            Text(
                              '한국 선수 $count명 참가',
                              style: TextStyle(
                                fontFamily: AppTypography.chivo,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.sp,
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
                    icon: Icon(Icons.close, color: subtleText, size: 22.sp),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      itemCount: players.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final p = players[index];
                        final name = p.name ?? '-';
                        final key = name.trim().toLowerCase();
                        final entry = _labels?[key];
                        return _playerRow(
                          index + 1,
                          name,
                          roundLabel: entry?.label,
                          eliminated: entry?.eliminated ?? false,
                          loading: _loading && _labels == null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerRow(
    int rank,
    String name, {
    String? roundLabel,
    bool eliminated = false,
    bool loading = false,
  }) {
    final isChamp = roundLabel == '우승';
    final chipColor = eliminated ? subtleText : accent;
    final chipBgAlpha = eliminated
        ? 0.10
        : (isChamp ? 0.32 : 0.16);
    final chipBorderAlpha = eliminated
        ? 0.25
        : (isChamp ? 0.7 : 0.4);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w900,
                fontSize: 11.sp,
                color: accent,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
                color: Colors.white,
              ),
            ),
          ),
          if (loading) ...[
            SizedBox(
              width: 12.w,
              height: 12.w,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: accent,
              ),
            ),
            SizedBox(width: 8.w),
          ] else if (roundLabel != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: chipBgAlpha),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: chipColor.withValues(alpha: chipBorderAlpha),
                ),
              ),
              child: Text(
                roundLabel,
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.sp,
                  color: chipColor,
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Text('🇰🇷', style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }

  Widget _emptyBody() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 36.sp, color: subtleText),
          SizedBox(height: 10.h),
          Text(
            '참가 선수 명단 정보가 아직 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: Colors.white),
          ),
          SizedBox(height: 4.h),
          Text(
            '대진이 발표되면 명단이 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: subtleText),
          ),
        ],
      ),
    );
  }
}

/// 라운드 우선순위 — 높을수록 후반. 미매칭은 0.
const Map<String, int> _kRoundRank = <String, int>{
  'R128': 1,
  'R64': 2,
  'R32': 3,
  'R16': 4,
  'QF': 5,
  'QUARTERFINAL': 5,
  'QUARTER-FINAL': 5,
  'SF': 6,
  'SEMIFINAL': 6,
  'SEMI-FINAL': 6,
  'F': 7,
  'FINAL': 7,
};

/// rank → 해당 라운드를 이긴 뒤 진출하는 다음 라운드 한글 라벨.
/// (예: R32 승리 → "16강", QF 승리 → "4강")
const Map<int, String> _kAdvancedLabel = <int, String>{
  1: '64강',
  2: '32강',
  3: '16강',
  4: '8강',
  5: '4강',
  6: '결승',
};

/// 라운드명 정규화: "Round of 32" → "R32", 공백/대소문자 무시.
String? _normalizeRound(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toUpperCase().replaceAll(' ', '');
  if (s.isEmpty) return null;
  final m = RegExp(r'ROUNDOF(\d+)').firstMatch(s);
  if (m != null) return 'R${m.group(1)}';
  return s;
}

/// 한국 선수 한 명의 진출 라운드 + 탈락 여부.
///
/// - 우승(결승 승리) → ("우승", false)
/// - 그 외 이긴 가장 후반 라운드 → (다음 라운드 라벨, 이후 패배 시 true)
/// - 이긴 경기가 없으면 → (가장 이른 미완료 매치의 라운드명, false);
///   미완료가 없는데 패배 매치만 있으면 (해당 라운드, true)
/// - 매치 자체가 없으면 → null
({String label, bool eliminated})? _labelForPlayer(
  String playerName,
  List<TournamentMatchResponse> matches,
) {
  final target = playerName.trim().toLowerCase();
  if (target.isEmpty) return null;

  bool hit(List<String>? names) {
    if (names == null || names.isEmpty) return false;
    for (final n in names) {
      final nl = n.trim().toLowerCase();
      if (nl.isEmpty) continue;
      if (nl == target || nl.contains(target) || target.contains(nl)) {
        return true;
      }
    }
    return false;
  }

  final mine = <TournamentMatchResponse>[];
  for (final m in matches) {
    if (hit(m.team1Names) || hit(m.team2Names)) mine.add(m);
  }
  if (mine.isEmpty) return null;

  var bestWonRank = 0;
  var bestLostRank = 0;
  var wonFinal = false;
  for (final m in mine) {
    if (!m.isCompleted) continue;
    final side = m.winnerSide;
    if (side == null) continue;
    final winnerNames = side == 1 ? m.team1Names : m.team2Names;
    final won = hit(winnerNames);

    final rank = _kRoundRank[_normalizeRound(m.roundName) ?? ''] ?? 0;
    if (won) {
      if (rank > bestWonRank) bestWonRank = rank;
      if (rank == 7) wonFinal = true;
    } else {
      if (rank > bestLostRank) bestLostRank = rank;
    }
  }

  // 미완료(예정) 매치 중 가장 이른 라운드
  var earliestRank = 1 << 30;
  String? earliestRound;
  for (final m in mine) {
    if (m.isCompleted) continue;
    final r = _normalizeRound(m.roundName);
    final rank = _kRoundRank[r ?? ''] ?? 0;
    if (rank > 0 && rank < earliestRank) {
      earliestRank = rank;
      earliestRound = r;
    }
  }

  if (wonFinal) return (label: '우승', eliminated: false);

  if (bestWonRank > 0) {
    final label = _kAdvancedLabel[bestWonRank] ?? '';
    if (label.isEmpty) return null;
    // 이긴 라운드보다 더 후반에서 패배했고, 그 이후 예정 경기가 없다면 탈락 확정.
    final eliminated = bestLostRank > bestWonRank && earliestRound == null;
    return (label: label, eliminated: eliminated);
  }

  // 이긴 경기 없음 — 패배만 있는 경우(첫 경기 탈락) 처리
  if (bestLostRank > 0 && earliestRound == null) {
    final r = _kRoundRank.entries
        .firstWhere((e) => e.value == bestLostRank, orElse: () => const MapEntry('', 0))
        .key;
    if (r.isEmpty) return null;
    return (label: r, eliminated: true);
  }

  if (earliestRound != null) {
    return (label: earliestRound, eliminated: false);
  }
  return null;
}
