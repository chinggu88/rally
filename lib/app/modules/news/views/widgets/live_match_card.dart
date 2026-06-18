import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/live_match_response.dart';

/// 라이브 매치 단일 카드 (홈 화면 상단 캐러셀에서 사용).
///
/// 스코어보드형 레이아웃 — 첨부 디자인을 따른다.
/// - 헤더: 라임 액센트 바 + 대회명(대문자), 그 아래 라운드 · 종목 라인
/// - 본문: 좌/우 선수 아바타(국가 코드 pill) + 가운데 현재 세트 큰 스코어 + "SET n"
/// - 이름 행: 아바타 아래 좌/우 선수명 (앞서는 쪽은 라임 강조)
/// - PREVIOUS SETS: 완료된 세트들을 박스로 나열
/// - 푸터: 코트명 pill (있을 경우)
///
/// [scoreBumpAt] 는 컨트롤러가 Realtime UPDATE로 스코어 변경을 감지했을 때
/// 갱신되는 타임스탬프. 값이 바뀔 때마다 카드 테두리 플래시 + 현재 스코어 펄스 1회.
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

  static const Color accent = AppColors.accent;
  static const Color accentDark = AppColors.accentDark;
  static const Color cardBg = AppColors.cardBg;
  static const Color cardBorder = AppColors.cardBorder;
  static const Color innerBg = AppColors.chipBg;
  static const Color subtleText = AppColors.subtleText;
  static const Color liveRed = Color(0xFFFF4D4F);

  @override
  State<LiveMatchCard> createState() => _LiveMatchCardState();
}

class _LiveMatchCardState extends State<LiveMatchCard>
    with TickerProviderStateMixin {
  /// 카드 전체 테두리 깜빡임용
  late final AnimationController _flashCtrl;

  /// 현재 세트 스코어 스케일 + 글로우용
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

  // ── 진행/결과 파생값 ──────────────────────────────────────────

  /// 화면에 큰 스코어로 보여줄 게임 인덱스.
  /// 진행 중이면 현재 게임, 종료/없으면 마지막 게임.
  int? get _displayGameIndex {
    final games = widget.match.games;
    if (games.isEmpty) return null;
    final cur = widget.match.currentGameIndex;
    if (cur != null) return cur;
    return games.length - 1;
  }

  /// 큰 스코어 기준으로 앞서는 쪽(1/2). 동점/판별불가 시 null.
  /// 종료 경기는 winnerSide를 우선한다.
  int? get _leadingSide {
    if (widget.match.isCompleted) {
      final w = widget.match.winnerSide;
      if (w != null) return w;
    }
    final idx = _displayGameIndex;
    if (idx == null) return null;
    final g = widget.match.games[idx];
    if (g.team1 > g.team2) return 1;
    if (g.team2 > g.team1) return 2;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width.w,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: AnimatedBuilder(
            animation: _flashCtrl,
            builder: (context, child) {
              // bump 시점에 accent(라임)으로 튀었다가 cardBorder(어두운 회색)으로 감쇠.
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
                  borderRadius: BorderRadius.circular(16.r),
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
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 10.h),
                  _buildRoundLine(),
                  SizedBox(height: 16.h),
                  // 가로 3열: [Team1] | [중앙 정보] | [Team2]
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1열: Team1 (아바타 + 이름)
                      _buildTeamColumn(side: 1),
                      // 2열: 스코어 + 세트 + 이전 세트 + 코트
                      Expanded(child: _buildCenterInfo()),
                      // 3열: Team2 (아바타 + 이름)
                      _buildTeamColumn(side: 2),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 헤더 (액센트 바 + 대회명) ─────────────────────────────────
  Widget _buildHeader() {
    final tournamentName = (widget.match.name ?? '').trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4.w,
          height: 22.h,
          decoration: BoxDecoration(
            color: LiveMatchCard.accent,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            (tournamentName.isEmpty ? '대회 정보 없음' : tournamentName)
                .toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 12.sp,
              height: 1.2,
              letterSpacing: 0.8,
              color: LiveMatchCard.subtleText,
            ),
          ),
        ),
      ],
    );
  }

  // ── 라운드 · 종목 라인 ───────────────────────────────────────
  Widget _buildRoundLine() {
    final round = _roundShort((widget.match.roundName ?? '').trim());
    final event =
        (widget.match.eventName ?? widget.match.categoryName ?? '')
            .trim()
            .toUpperCase();

    final children = <Widget>[];
    if (round.isNotEmpty) {
      children.add(
        Text(
          round,
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 22.sp,
            height: 1.0,
            letterSpacing: 0.3,
            color: Colors.white,
          ),
        ),
      );
    }
    if (round.isNotEmpty && event.isNotEmpty) {
      children.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Icon(Icons.circle, size: 6.sp, color: LiveMatchCard.accent),
        ),
      );
    }
    if (event.isNotEmpty) {
      children.add(
        Text(
          event,
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 22.sp,
            height: 1.0,
            letterSpacing: 0.3,
            color: LiveMatchCard.accent,
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  // ── 팀 컬럼 (아바타 위, 이름 아래) ────────────────────────────
  Widget _buildTeamColumn({required int side}) {
    final leading = _leadingSide;
    final highlight = leading == side;
    final avatars =
        side == 1
            ? widget.match.team1PlayerAvatars
            : widget.match.team2PlayerAvatars;
    final names = side == 1 ? widget.match.team1Names : widget.match.team2Names;
    final country =
        ((side == 1 ? widget.match.team1Country : widget.match.team2Country) ??
                '')
            .trim();
    final display =
        side == 1 ? widget.match.team1Display : widget.match.team2Display;
    final count = (names?.length ?? 1).clamp(1, 2);
    final align = side == 1 ? TextAlign.left : TextAlign.right;

    return SizedBox(
      width: 96.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatarBlock(
            avatars: avatars,
            count: count,
            country: country,
            highlight: highlight,
          ),
          SizedBox(height: 10.h),
          _nameLabel(display, align: align, highlight: highlight),
        ],
      ),
    );
  }

  // ── 중앙 정보 (현재 스코어 + 세트 + 이전 세트 + 코트) ─────────────
  Widget _buildCenterInfo() {
    final courtName = (widget.match.courtName ?? '').trim();
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.match.isLive)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    fontFamily: AppTypography.chivo,
                    fontWeight: FontWeight.w900,
                    fontSize: 68.sp,
                    letterSpacing: 4,
                    color: Colors.white.withValues(alpha: 0.045),
                  ),
                ),
              ),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBigScore(),
            ..._buildPreviousSets(),
            if (courtName.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _buildCourtFooter(courtName),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBigScore() {
    final idx = _displayGameIndex;
    final leading = _leadingSide;

    if (idx == null) {
      // 게임 스코어가 없을 때: 폴백 문자열 또는 대기 라벨.
      final fallback = (widget.match.scoreDisplay ?? '').trim();
      return Center(
        child: Text(
          fallback.isEmpty ? '경기 시작 대기' : fallback,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: fallback.isEmpty ? 13.sp : 18.sp,
            letterSpacing: 0.4,
            color: fallback.isEmpty ? LiveMatchCard.subtleText : Colors.white,
          ),
        ),
      );
    }

    final g = widget.match.games[idx];
    final setNo = idx + 1;
    final completed = widget.match.isCompleted;

    Color scoreColor(int side) {
      if (leading == side) return LiveMatchCard.accent;
      return Colors.white;
    }

    final scoreRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${g.team1}',
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 40.sp,
            height: 1.0,
            color: scoreColor(1),
          ),
        ),
        // SizedBox(width: 14.w),
        Text(
          ':',
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 30.sp,
            height: 1.0,
            color: Colors.white,
          ),
        ),
        Text(
          '${g.team2}',
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 40.sp,
            height: 1.0,
            color: scoreColor(2),
          ),
        ),
      ],
    );

    // 스코어 변경 시 펄스(스케일 + 글로우).
    final pulsingScore = AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final v = _pulseCtrl.value;
        final pulse = 1.0 + 0.12 * _pulseShape(v);
        return Transform.scale(scale: pulse, child: child);
      },
      child: scoreRow,
    );

    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulsingScore,
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!completed) ...[
                Container(
                  width: 5.w,
                  height: 5.w,
                  decoration: const BoxDecoration(
                    color: LiveMatchCard.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5.w),
              ],
              Text(
                completed ? 'FINAL' : 'SET $setNo',
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.sp,
                  letterSpacing: 1.0,
                  color: LiveMatchCard.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 선수 아바타 블록 (라운드 사각형 + 국가 코드 pill) ──────────────
  Widget _buildAvatarBlock({
    required List<String>? avatars,
    required int count,
    required String country,
    required bool highlight,
  }) {
    final code = country.toUpperCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(avatars: avatars, count: count, highlight: highlight),
        if (code.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: LiveMatchCard.accent,
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w800,
                fontSize: 9.sp,
                letterSpacing: 0.6,
                color: LiveMatchCard.accentDark,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar({
    required List<String>? avatars,
    required int count,
    required bool highlight,
  }) {
    String? urlAt(int i) {
      if (avatars == null || i >= avatars.length) return null;
      final u = avatars[i].trim();
      return u.isEmpty ? null : u;
    }

    if (count >= 2) {
      // 복식: 독립된 두 컨테이너를 최소한으로 겹쳐 대각선으로 배치.
      final double size = 48.w;
      final double offset = 38.w; // size보다 작게 → 살짝(10px)만 겹침
      final double total = size + offset;
      return SizedBox(
        width: total,
        height: total,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 첫 번째 선수: 좌상단
            Positioned(
              left: 0,
              top: 0,
              child: _avatarFrame(
                _avatarImage(urlAt(0)),
                size: size,
                highlight: highlight,
              ),
            ),
            // 두 번째 선수: 우하단 (위에 겹쳐 그려져 경계가 드러남)
            Positioned(
              right: 0,
              bottom: 0,
              child: _avatarFrame(
                _avatarImage(urlAt(1)),
                size: size,
                highlight: highlight,
                gap: true,
              ),
            ),
          ],
        ),
      );
    }

    // 단식: 단일 컨테이너.
    return _avatarFrame(
      _avatarImage(urlAt(0)),
      size: 70.w,
      highlight: highlight,
    );
  }

  /// 라운드 사각형 아바타 프레임.
  ///
  /// [gap] 이 true이면 겹친 아바타가 서로 분리돼 보이도록 cardBg 외곽 링을 추가한다.
  Widget _avatarFrame(
    Widget child, {
    required double size,
    required bool highlight,
    bool gap = false,
  }) {
    final borderColor =
        highlight ? LiveMatchCard.accent : LiveMatchCard.cardBorder;
    final frame = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: LiveMatchCard.innerBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor, width: highlight ? 2 : 1),
        boxShadow:
            highlight
                ? [
                  BoxShadow(
                    color: LiveMatchCard.accent.withValues(alpha: 0.22),
                    blurRadius: 12,
                    spreadRadius: 0.5,
                  ),
                ]
                : null,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(13.r), child: child),
    );

    if (!gap) return frame;
    // 겹치는 쪽 아바타에 카드 배경색 외곽 링을 둘러 경계를 분리.
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: LiveMatchCard.cardBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: frame,
    );
  }

  Widget _avatarImage(String? url) {
    final placeholder = Container(
      color: LiveMatchCard.innerBg,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 26.sp, color: LiveMatchCard.subtleText),
    );
    if (url == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: LiveMatchCard.innerBg),
      errorWidget: (_, __, ___) => placeholder,
    );
  }

  Widget _nameLabel(
    String name, {
    required TextAlign align,
    required bool highlight,
  }) {
    final style = TextStyle(
      fontFamily: AppTypography.chivo,
      fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
      fontSize: 14.sp,
      height: 1.15,
      letterSpacing: 0.5,
      color: highlight ? LiveMatchCard.accent : Colors.white,
    );

    // 복식: "/" 기준으로 분리해 선수별 한 줄씩(최대 2줄), 줄별로 넘치면 "..." 표시.
    final parts =
        name
            .split('/')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (parts.length >= 2) {
      return Column(
        crossAxisAlignment:
            align == TextAlign.right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in parts.take(2))
            Text(
              p.toUpperCase(),
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
        ],
      );
    }

    // 단식: 한 선수명, 넘치면 2줄까지 후 "..." 표시.
    return Text(
      name.toUpperCase(),
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  // ── PREVIOUS (완료된 세트 점수 — 현재 스코어 아래 세로 나열) ─────────
  List<Widget> _buildPreviousSets() {
    final idx = _displayGameIndex;
    if (idx == null || idx <= 0) return const <Widget>[];
    final games = widget.match.games;
    final previous = games.sublist(0, idx);
    if (previous.isEmpty) return const <Widget>[];

    return [
      SizedBox(height: 12.h),
      Text(
        'PREVIOUS',
        style: TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 9.sp,
          letterSpacing: 1.4,
          color: LiveMatchCard.subtleText,
        ),
      ),
      SizedBox(height: 7.h),
      for (int i = 0; i < previous.length; i++) ...[
        _buildSetRow(
          setNo: i + 1,
          game: previous[i],
          highlight: i == previous.length - 1,
        ),
        if (i < previous.length - 1) SizedBox(height: 6.h),
      ],
    ];
  }

  /// 지난 세트 한 줄 박스 — "S{n}  점수:점수" 형태.
  Widget _buildSetRow({
    required int setNo,
    required LiveGameScore game,
    required bool highlight,
  }) {
    final t1won = game.team1 > game.team2;
    final t2won = game.team2 > game.team1;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: LiveMatchCard.innerBg,
        borderRadius: BorderRadius.circular(7.r),
        border: Border.all(
          color: highlight ? LiveMatchCard.accent : LiveMatchCard.cardBorder,
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'S$setNo',
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w700,
              fontSize: 9.sp,
              letterSpacing: 0.6,
              color: LiveMatchCard.subtleText,
            ),
          ),
          SizedBox(width: 7.w),
          Text(
            '${game.team1}',
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 13.sp,
              height: 1.0,
              color: t1won ? LiveMatchCard.accent : Colors.white,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              ':',
              style: TextStyle(
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w700,
                fontSize: 11.sp,
                color: LiveMatchCard.subtleText,
              ),
            ),
          ),
          Text(
            '${game.team2}',
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 13.sp,
              height: 1.0,
              color: t2won ? LiveMatchCard.accent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── 푸터 (코트명 pill) ────────────────────────────────────────
  Widget _buildCourtFooter(String courtName) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: LiveMatchCard.innerBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: LiveMatchCard.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 13.sp,
              color: LiveMatchCard.subtleText,
            ),
            SizedBox(width: 5.w),
            Text(
              courtName.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTypography.chivo,
                fontWeight: FontWeight.w700,
                fontSize: 11.sp,
                letterSpacing: 0.6,
                color: LiveMatchCard.subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────

  /// 0..1 → 0..1..0 의 부드러운 산 모양 (펄스 1회).
  double _pulseShape(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 0;
    return (t < 0.5 ? t * 2 : (1 - t) * 2);
  }

  /// 라운드명을 짧은 코드로 축약. (예: "Round of 16" → "R16", "Quarter-final" → "QF")
  String _roundShort(String round) {
    if (round.isEmpty) return '';
    final lower = round.toLowerCase();

    final roundOf = RegExp(r'round\s*of\s*(\d+)').firstMatch(lower);
    if (roundOf != null) return 'R${roundOf.group(1)}';

    if (lower.contains('quarter')) return 'QF';
    if (lower.contains('semi')) return 'SF';
    if (lower == 'final' || lower.contains('final')) {
      // "final"만 단독이면 FINAL, 그 외 (예: "semi-final")는 위에서 처리됨.
      return 'FINAL';
    }
    if (lower.contains('qualif')) return 'QUAL';

    // 그 외에는 원본을 대문자로 (최대 6자).
    final up = round.toUpperCase();
    return up.length <= 6 ? up : up.substring(0, 6);
  }
}
