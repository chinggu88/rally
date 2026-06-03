import 'dart:developer';

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
///
/// [scoreBumpAt] 는 컨트롤러가 Realtime UPDATE로 스코어 변경을 감지했을 때
/// 갱신되는 타임스탬프. 값이 바뀔 때마다 현재 게임 pill과 숫자가 펄스 한 번.
class LiveMatchCard extends StatefulWidget {
  const LiveMatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.width = 320,
    this.scoreBumpAt,
  });

  final LiveMatchResponse match;
  final VoidCallback? onTap;
  final double width;
  final DateTime? scoreBumpAt;

  static const Color accent = Color(0xFFC3F400);
  static const Color accentDark = Color(0xFF283500);
  static const Color cardBg = Color(0xFF1C1B1B);
  static const Color cardBorder = Color(0xFF2A2A2A);
  static const Color subtleText = Color(0xFF9CA3A1);
  static const Color liveRed = Color(0xFFFF4D4F);

  @override
  State<LiveMatchCard> createState() => _LiveMatchCardState();
}

class _LiveMatchCardState extends State<LiveMatchCard>
    with TickerProviderStateMixin {
  /// 카드 전체 테두리 깜빡임용
  late final AnimationController _flashCtrl;

  /// 현재 게임 pill 스케일 + 글로우용
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(covariant LiveMatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 매치 id가 바뀐 경우(같은 State에 다른 매치가 들어온 경우 = 리스트 정렬/삭제)
    // 이전 매치의 bump 잔상이 남지 않도록 애니메이션을 강제로 리셋한다.
    final prevId = oldWidget.match.id;
    final currId = widget.match.id;
    if (prevId != currId) {
      _flashCtrl.stop();
      _flashCtrl.value = 0;
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
      return;
    }
    // 같은 매치에 대해 새 bump 타임스탬프가 내려온 경우에만 애니메이션 재생.
    final newBump = widget.scoreBumpAt;
    final oldBump = oldWidget.scoreBumpAt;
    if (newBump != null && newBump != oldBump) {
      _flashCtrl.forward(from: 0);
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedBuilder(
            animation: _flashCtrl,
            builder: (context, child) {
              // bump 시점에 accent(라임)으로 튀었다가 cardBorder(어두운 회색)으로 감쇠.
              // - _flashCtrl.value == 0 (정지/초기): t = 0 → cardBorder
              // - _flashCtrl.value 가 forward 직후 빠르게 1로 갔다가 0으로 감쇠
              //   하는 게 아니라, AnimationController 자체는 0 → 1 선형이므로
              //   "강도"는 1 - value 로 계산해 시작 순간만 가장 강하게.
              // 단, 정지 상태(value == 0)와 종료 상태(value == 1) 모두 t == 0 이 되도록
              //   bump 발생 시 별도 처리: forward 중 status 가 forward 일 때만 강도 부여.
              final raw = _flashCtrl.value;
              final isFlashing = _flashCtrl.isAnimating;
              final t = isFlashing ? (1.0 - raw).clamp(0.0, 1.0) : 0.0;
              final borderColor =
                  Color.lerp(
                    LiveMatchCard.cardBorder,
                    LiveMatchCard.accent,
                    t,
                  )!;
              return Container(
                decoration: BoxDecoration(
                  color: LiveMatchCard.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.0 + t * 1.2),
                  boxShadow:
                      t > 0.01
                          ? [
                            BoxShadow(
                              color: LiveMatchCard.accent.withValues(
                                alpha: 0.35 * t,
                              ),
                              blurRadius: 18 * t,
                              spreadRadius: 1 * t,
                            ),
                          ]
                          : null,
                ),
                child: child,
              );
            },
            child: Padding(
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
                    display: widget.match.team1Display,
                    country: (widget.match.team1Country ?? '').trim(),
                    seed: (widget.match.team1Seed ?? '').trim(),
                    avatars: widget.match.team1PlayerAvatars,
                    playerCount: widget.match.team1Names?.length ?? 1,
                  ),
                  const SizedBox(height: 8),
                  _buildScoreLine(),
                  const SizedBox(height: 8),
                  _buildTeamRow(
                    side: 2,
                    display: widget.match.team2Display,
                    country: (widget.match.team2Country ?? '').trim(),
                    seed: (widget.match.team2Seed ?? '').trim(),
                    avatars: widget.match.team2PlayerAvatars,
                    playerCount: widget.match.team2Names?.length ?? 1,
                  ),
                  if ((widget.match.courtName ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildCourtFooter(widget.match.courtName!.trim()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 헤더 (로고 + 대회명 + LIVE 배지) ─────────────────────────
  Widget _buildHeader() {
    final logo = widget.match.displayLogoUrl;
    final tournamentName = (widget.match.name ?? '').trim();
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
          color: LiveMatchCard.subtleText,
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
        placeholder:
            (_, __) => Container(
              width: size,
              height: size,
              color: const Color(0xFF2A2A2A),
            ),
        errorWidget:
            (_, __, ___) => Container(
              width: size,
              height: size,
              color: const Color(0xFF2A2A2A),
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                size: 14,
                color: LiveMatchCard.subtleText,
              ),
            ),
      ),
    );
  }

  // ── 종목·라운드 라인 ──────────────────────────────────────
  Widget _buildEventLine() {
    final parts = <String>[];
    final ev = (widget.match.eventName ?? '').trim();
    if (ev.isNotEmpty) parts.add(ev);
    final round = (widget.match.roundName ?? '').trim();
    if (round.isNotEmpty) parts.add(round);
    final category = (widget.match.categoryName ?? '').trim();
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
        color: LiveMatchCard.accent,
      ),
    );
  }

  // ── 팀 row (아바타/국기/시드/이름) ──────────────────────────────────
  Widget _buildTeamRow({
    required int side,
    required String display,
    required String country,
    required String seed,
    List<String>? avatars,
    int playerCount = 1,
  }) {
    final flag = flagEmoji(country);
    final isWinner = widget.match.winnerSide == side;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 선수 프로필 아바타 (단식 1개, 복식 2개) — URL은 추후 edge function에서 제공.
        _buildPlayerAvatars(avatars: avatars, count: playerCount.clamp(1, 2)),
        const SizedBox(width: 8),
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
              color: LiveMatchCard.accentDark,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              seed,
              style: const TextStyle(
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.4,
                color: LiveMatchCard.accent,
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
              color: isWinner ? LiveMatchCard.accent : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ── 스코어 라인 (게임별 점수 또는 폴백 문자열) ─────────────
  Widget _buildScoreLine() {
    final games = widget.match.games;
    if (games.isNotEmpty) {
      final currentIdx = widget.match.currentGameIndex;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < games.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildGamePill(game: games[i], isCurrent: i == currentIdx),
          ],
        ],
      );
    }

    final fallback = (widget.match.scoreDisplay ?? '').trim();
    if (fallback.isEmpty) {
      return Text(
        '경기 시작 대기',
        style: AppTypography.bodyMd.copyWith(
          color: LiveMatchCard.subtleText,
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
    final bg = isCurrent ? LiveMatchCard.accent : const Color(0xFF201F1F);
    final border = isCurrent ? LiveMatchCard.accent : const Color(0xFF2A2A2A);
    final fg = isCurrent ? LiveMatchCard.accentDark : Colors.white;

    final scoreText = '${game.team1}-${game.team2}';

    // 숫자가 바뀔 때 AnimatedSwitcher로 페이드 + 미세 슬라이드.
    final scoreLabel = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) {
        final offsetAnim = Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return ClipRect(
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(position: offsetAnim, child: child),
          ),
        );
      },
      child: Text(
        scoreText,
        key: ValueKey<String>(scoreText),
        style: TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );

    // 현재 게임 pill에는 스코어 변경 시 펄스(스케일 + 글로우) 추가.
    final pillCore = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: scoreLabel,
    );

    if (!isCurrent) return pillCore;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        // 0 → 1로 가며 1.0 → 1.18 → 1.0 펄스. 이중 sin으로 부드럽게.
        final v = _pulseCtrl.value;
        final pulse = 1.0 + 0.18 * _pulseShape(v);
        final glow = 0.55 * _pulseShape(v);
        return Transform.scale(
          scale: pulse,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow:
                  glow > 0.01
                      ? [
                        BoxShadow(
                          color: LiveMatchCard.accent.withValues(alpha: glow),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
            child: child,
          ),
        );
      },
      child: pillCore,
    );
  }

  /// 0..1 → 0..1..0 의 부드러운 산 모양 (펄스 1회).
  double _pulseShape(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 0;
    // sin(πt) → 0..1..0
    return (t < 0.5 ? t * 2 : (1 - t) * 2);
  }

  // ── 선수 프로필 아바타 ──────────────────────────────────
  /// 선수 아바타 스택 (단식 1개 / 복식 2개 살짝 겹친 형태).
  ///
  /// [avatars]는 URL 목록(인덱스는 선수 순서). null/짧으면 placeholder 원으로 채움.
  /// 추후 edge function에서 `team{1,2}_player_avatars` 배열을 제공할 예정이며,
  /// 그 시점이 와도 본 위젯은 그대로 동작한다.
  Widget _buildPlayerAvatars({
    required List<String>? avatars,
    required int count,
  }) {
    const double size = 22;
    const double overlap = 8; // 두 아바타가 겹치는 폭
    final width = count == 1 ? size : size * 2 - overlap;

    String? urlAt(int i) {
      if (avatars == null || i >= avatars.length) return null;
      final u = avatars[i].trim();
      return u.isEmpty ? null : u;
    }

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 0, child: _avatarCircle(urlAt(0), size)),
          if (count >= 2)
            Positioned(
              left: size - overlap,
              top: 0,
              child: _avatarCircle(urlAt(1), size),
            ),
        ],
      ),
    );
  }

  Widget _avatarCircle(String? url, double size) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        shape: BoxShape.circle,
        border: Border.all(color: LiveMatchCard.cardBg, width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline,
        size: 13,
        color: LiveMatchCard.subtleText,
      ),
    );

    if (url == null) return placeholder;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: LiveMatchCard.cardBg, width: 1.5),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: const Color(0xFF2A2A2A)),
          errorWidget: (_, __, ___) => placeholder,
        ),
      ),
    );
  }

  // ── 푸터 (코트명) ────────────────────────────────────────
  Widget _buildCourtFooter(String courtName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.stadium_outlined,
          size: 12,
          color: LiveMatchCard.subtleText,
        ),
        const SizedBox(width: 4),
        Text(
          courtName,
          style: const TextStyle(
            fontFamily: AppTypography.sourceSans,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: LiveMatchCard.subtleText,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
