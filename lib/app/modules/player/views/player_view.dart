import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/player_response.dart';
import '../../../utils/country_flag.dart';
import '../controllers/player_controller.dart';

/// 선수 화면 — Stitch: 선수 리스트 (매거진)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : eeae55cab3614d408743636d325e3b88
class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  PlayerController get controller => PlayerController.to;

  // Stitch 디자인 토큰 (AppColors와 정합되지 않는 시안 디테일만 별도 상수로 보존)
  static const Color _accent = AppColors.accent;
  static const Color _accentDark = AppColors.accentDark;
  static const Color _subtleText = AppColors.subtleText;

  final ScrollController _scroll = ScrollController();
  Worker? _resetSignalWorker;

  /// 무한 스크롤 트리거 임계값 — 바닥에서 이만큼 떨어진 지점부터 loadMore 시작
  static const double _loadMoreThreshold = 300.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // 탭 진입 신호 — 컨트롤러가 resetSignal을 증가시키면 스크롤 상단으로 점프
    _resetSignalWorker = ever<int>(controller.resetSignal, (_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThreshold) {
      controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _resetSignalWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 12.h),
            _buildCategoryChips(),
            SizedBox(height: 12.h),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refreshPlayers,
                color: _accent,
                backgroundColor: scheme.surfaceContainer,
                child: _buildContent(scheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.dark.surface,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Rally',
        style: TextStyle(
          color: _accent,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 18.sp,
          letterSpacing: 0.2,
        ),
      ),
      leading: Padding(
        padding: EdgeInsets.only(left: 12.w),
        child: const Icon(Icons.menu, color: Colors.white),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: const Icon(Icons.search, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // 상태 분기: 로딩/에러/빈 상태일 땐 단일 sliver, 정상이면 SliverList
        Obx(() {
          if (controller.isLoading) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80.h),
                child: const Center(
                  child: CircularProgressIndicator(color: _accent),
                ),
              ),
            );
          }
          final error = controller.errorMessage;
          if (error != null && controller.players.isEmpty) {
            return SliverToBoxAdapter(child: _buildErrorState(error));
          }
          if (controller.players.isEmpty) {
            return SliverToBoxAdapter(child: _buildEmptyState());
          }
          return _buildPlayerSliverList(controller.players);
        }),
        // 추가 페이지 로딩 인디케이터 — isLoadingMore일 때만 표시
        SliverToBoxAdapter(
          child: Obx(() {
            if (!controller.isLoadingMore) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            );
          }),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 32.h)),
      ],
    );
  }

  /// 카테고리 칩 그룹 (MS / WS / MD / WD / XD — 가로 스크롤 가능)
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44.h,
      child: Obx(() {
        final selected = controller.selectedCategory;
        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          scrollDirection: Axis.horizontal,
          itemCount: PlayerController.categories.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (context, index) {
            final code = PlayerController.categories[index];
            final isSelected = code == selected;
            return _CategoryChip(
              code: code,
              label: PlayerController.labelEnOf(code),
              koLabel: PlayerController.labelKoOf(code),
              selected: isSelected,
              onTap: () => controller.changeCategory(code),
            );
          },
        );
      }),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 60.h),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 48.sp, color: _subtleText),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 44.h,
            child: ElevatedButton(
              onPressed: controller.refreshPlayers,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _accentDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w),
              ),
              child: Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
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
      padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 60.h),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 48.sp, color: _subtleText),
          SizedBox(height: 12.h),
          Obx(
            () => Text(
              '${PlayerController.labelKoOf(controller.selectedCategory)} '
              '랭킹 데이터가 없습니다.',
              style: AppTypography.bodyMd.copyWith(color: Colors.white),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '다른 종목을 선택해보세요.',
            style: AppTypography.bodyMd.copyWith(color: _subtleText),
          ),
        ],
      ),
    );
  }

  /// 선수 카드 SliverList (rank 오름차순) — 지연 빌드로 큰 목록도 가볍게 처리
  Widget _buildPlayerSliverList(List<PlayerResponse> list) {
    final isDoubles = _isDoublesCategory(controller.selectedCategory);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
      sliver: SliverList.separated(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final p = list[i];
          return _PlayerCard(
            player: p,
            isDoubles: isDoubles,
            onTap: () => controller.openPlayerDetail(p),
            onTapDoublesPlayer1: () {
              final (n1, _) = _PlayerCard.splitDoublesNames(p.playerName);
              controller.openDoublesPlayerDetail(
                p: p,
                playerId: p.player1Id,
                playerName: n1.isEmpty ? p.playerName : n1,
              );
            },
            onTapDoublesPlayer2: () {
              final (_, n2) = _PlayerCard.splitDoublesNames(p.playerName);
              controller.openDoublesPlayerDetail(
                p: p,
                playerId: p.player2Id,
                playerName: n2.isEmpty ? p.playerName : n2,
              );
            },
          );
        },
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
      ),
    );
  }

  static bool _isDoublesCategory(String code) =>
      code == 'MD' || code == 'WD' || code == 'XD';
}

/// 카테고리 선택 칩 (선택 시 라임 옐로우 fill)
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.code,
    required this.label,
    required this.koLabel,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final String koLabel;
  final bool selected;
  final VoidCallback onTap;

  static const Color _accent = AppColors.accent;
  static const Color _accentDark = AppColors.accentDark;
  static const Color _chipBg = AppColors.chipBg;
  static const Color _chipBorder = AppColors.cardBorder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? _accent : _chipBg,
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(color: selected ? _accent : _chipBorder),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.sp,
                  letterSpacing: 0.6,
                  color: selected ? _accentDark : _accent,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                koLabel,
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                  letterSpacing: 0.2,
                  color: selected ? _accentDark : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선수 단일 카드 (매거진 스타일)
///
/// - 좌측: 큰 랭킹 숫자 (`#1` 형식, 라임 옐로우 액센트 + 선수 사진 반투명 중첩)
/// - 중앙: 선수명 + 국기/국가명
/// - 우측: 화살표 (탭 진입 affordance)
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.isDoubles,
    required this.onTap,
    this.onTapDoublesPlayer1,
    this.onTapDoublesPlayer2,
  });

  final PlayerResponse player;

  /// 복식(MD/WD/XD) 카테고리 여부. true면 좌측에 두 선수 아바타를 겹쳐 표시.
  final bool isDoubles;

  /// 단식 카드 전체 탭, 또는 복식 카드의 비-선수 영역(랭킹/포인트 영역) 탭 콜백.
  final VoidCallback onTap;

  /// 복식 카드에서 첫 번째 선수 행을 탭했을 때 호출 — null이면 분리 탭 비활성.
  final VoidCallback? onTapDoublesPlayer1;

  /// 복식 카드에서 두 번째 선수 행을 탭했을 때 호출 — null이면 분리 탭 비활성.
  final VoidCallback? onTapDoublesPlayer2;

  static const Color _accent = AppColors.accent;
  static const Color _cardBg = AppColors.cardBg;
  static const Color _cardBorder = AppColors.cardBorder;
  static const Color _subtleText = AppColors.subtleText;

  // 순위 변동 색상
  static const Color _upGreen = Color(0xFF4ADE80);
  static const Color _downRed = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    if (isDoubles) return _buildDoublesCard();
    return _buildSinglesCard();
  }

  Widget _buildSinglesCard() {
    final rank = player.rank;
    final name = (player.playerName ?? '').trim();
    final country = (player.countryCode ?? '').trim();
    final countryName = (player.countryName ?? '').trim();
    final displayName = name.isEmpty ? '—' : name;
    final displayCountry =
        countryName.isNotEmpty
            ? countryName
            : (country.isEmpty ? '—' : country.toUpperCase());
    // country_name 우선(대부분의 행에서 country_code는 null), 폴백으로 ISO3 사용.
    final flag =
        countryName.isNotEmpty
            ? flagEmojiFromName(countryName)
            : flagEmoji(country);
    final rankLabel = rank != null ? '#$rank' : '#—';
    final pointsText = _formatPoints(player.points);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _cardBorder),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 좌측: 선수 사진
              _buildAvatar(player.photoUrl),
              SizedBox(width: 16.w),
              // 중앙: 순위+이름 / 국가 / 포인트·변동
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1행: 랭킹 숫자 + 선수명
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          rankLabel,
                          style: TextStyle(
                            fontFamily: AppTypography.chivo,
                            fontWeight: FontWeight.w800,
                            fontSize: 18.sp,
                            height: 1.15,
                            letterSpacing: -0.5,
                            color: _accent,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineMd.copyWith(
                              color: Colors.white,
                              fontSize: 19.sp,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    // 2행: 국기 + 국가명
                    Row(
                      children: [
                        if (flag.isNotEmpty)
                          Text(flag, style: TextStyle(fontSize: 14.sp))
                        else
                          Container(
                            width: 14.w,
                            height: 14.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF353534),
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                            child: Icon(
                              Icons.flag_outlined,
                              color: _subtleText,
                              size: 10.sp,
                            ),
                          ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            displayCountry,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelLg.copyWith(
                              color: _subtleText,
                              fontSize: 12.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 3행: 랭킹 포인트 + 순위 변동
                    if (pointsText.isNotEmpty || player.rankChange != null) ...[
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          if (pointsText.isNotEmpty) ...[
                            Icon(Icons.bolt, color: _accent, size: 14.sp),
                            SizedBox(width: 3.w),
                            Text(
                              pointsText,
                              style: AppTypography.labelLg.copyWith(
                                color: Colors.white,
                                fontSize: 12.sp,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              ' P',
                              style: AppTypography.labelLg.copyWith(
                                color: _subtleText,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                          if (pointsText.isNotEmpty &&
                              player.rankChange != null)
                            SizedBox(width: 10.w),
                          _buildRankChange(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // 우측: 진입 화살표
              Icon(Icons.arrow_forward, color: Colors.white, size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }

  /// 선수 사진 — 오버레이 없이 이미지만 (없으면 인물 아이콘 플레이스홀더).
  Widget _buildAvatar(String? photoUrl) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 64.w,
        height: 64.w,
        color: AppColors.surfaceAlt2,
        child:
            hasPhoto
                ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _avatarPlaceholder();
                  },
                )
                : _avatarPlaceholder(),
      ),
    );
  }

  /// 복식(MD/WD/XD) 카드 — 두 선수가 각자 한 줄(원형 아바타 + 이름 + 국가).
  ///
  /// 좌측에 단식과 동일한 `#N` 라임 옐로우 랭킹 라벨, 우측 세로 중앙에
  /// 큰 포인트 + 순위 변동.
  Widget _buildDoublesCard() {
    final rank = player.rank;
    final country = (player.countryCode ?? '').trim();
    final countryName = (player.countryName ?? '').trim();
    final displayCountry =
        countryName.isNotEmpty
            ? countryName
            : (country.isEmpty ? '—' : country.toUpperCase());
    final flag =
        countryName.isNotEmpty
            ? flagEmojiFromName(countryName)
            : flagEmoji(country);
    final pointsText = _formatPoints(player.points);
    final rankLabel = rank != null ? '#$rank' : '#—';

    final names = splitDoublesNames(player.playerName);
    final p1Display = _formatDoublesName(names.$1);
    final p2Display = _formatDoublesName(names.$2);

    // 복식 카드는 두 선수의 영역을 분리해 각자 상세 페이지로 이동할 수 있도록
     // 외곽 InkWell 대신 컨테이너 + 행마다 InkWell을 사용한다.
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _cardBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 좌측: 단식과 동일한 #N 라벨
          Text(
            rankLabel,
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 18.sp,
              height: 1.15,
              letterSpacing: -0.5,
              color: _accent,
            ),
          ),
          SizedBox(width: 12.w),
          // 중앙: 두 선수의 행 (각 행이 독립 탭 가능)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTappableDoublesRow(
                  photoUrl: player.photoUrl,
                  firstName: p1Display.first,
                  lastName: p1Display.last,
                  flag: flag,
                  country: displayCountry,
                  onTap: onTapDoublesPlayer1 ?? onTap,
                ),
                SizedBox(height: 10.h),
                _buildTappableDoublesRow(
                  photoUrl: player.photoUrl2,
                  firstName: p2Display.first,
                  lastName: p2Display.last,
                  flag: flag,
                  country: displayCountry,
                  onTap: onTapDoublesPlayer2 ?? onTap,
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // 우측: 포인트 + 순위 변동 (세로 중앙)
          _buildDoublesTrailing(pointsText),
        ],
      ),
    );
  }

  /// 복식 카드 한 선수의 행을 탭 가능하게 감싸는 래퍼.
  Widget _buildTappableDoublesRow({
    required String? photoUrl,
    required String firstName,
    required String lastName,
    required String flag,
    required String country,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: _buildDoublesPlayerRow(
            photoUrl: photoUrl,
            firstName: firstName,
            lastName: lastName,
            flag: flag,
            country: country,
          ),
        ),
      ),
    );
  }

  /// 복식 카드 한 선수의 행 — 원형 아바타 + "First / LASTNAME / 국가".
  Widget _buildDoublesPlayerRow({
    required String? photoUrl,
    required String firstName,
    required String lastName,
    required String flag,
    required String country,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildRoundAvatar(photoUrl, size: 36.w),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (firstName.isNotEmpty)
                Text(
                  firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg.copyWith(
                    color: _subtleText,
                    fontSize: 11.sp,
                    letterSpacing: 0.4,
                    height: 1.0,
                  ),
                ),
              SizedBox(height: 2.h),
              Text(
                lastName.isEmpty ? '—' : lastName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                  color: _accent,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  if (flag.isNotEmpty) ...[
                    Text(flag, style: TextStyle(fontSize: 11.sp)),
                    SizedBox(width: 4.w),
                  ],
                  Flexible(
                    child: Text(
                      country,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLg.copyWith(
                        color: _subtleText,
                        fontSize: 11.sp,
                        letterSpacing: 0.3,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 복식 카드 우측 — 큰 포인트 숫자 + 순위 변동 보조 라인.
  Widget _buildDoublesTrailing(String pointsText) {
    final hasPoints = pointsText.isNotEmpty;
    final hasChange = player.rankChange != null;
    if (!hasPoints && !hasChange) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (hasPoints)
          Text(
            pointsText,
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 16.sp,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -0.2,
            ),
          ),
        if (hasChange) ...[SizedBox(height: 4.h), _buildRankChange()],
      ],
    );
  }

  /// 원형 아바타 (얼굴이 상단에 위치하는 경향을 고려해 상단 정렬).
  Widget _buildRoundAvatar(String? photoUrl, {required double size}) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceAlt2,
        child:
            hasPhoto
                ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.4),
                  errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _avatarPlaceholder();
                  },
                )
                : _avatarPlaceholder(),
      ),
    );
  }

  /// `"FIRST LASTNAME / FIRST LASTNAME"` → 두 부분으로 분리. 슬래시가 없으면 두 번째는 빈 문자열.
  static (String, String) splitDoublesNames(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return ('', '');
    final parts = s.split(RegExp(r'\s*/\s*'));
    final first = parts.isNotEmpty ? parts[0].trim() : '';
    final second = parts.length > 1 ? parts[1].trim() : '';
    return (first, second);
  }

  /// BWF 표기 "Dechapol PUAVARANUKROH" → first="DECHAPOL" / last="PUAVARANUKROH".
  /// 대문자 토큰을 성으로, 그 외를 이름으로 본다. 토큰 구분이 어려우면
  /// 마지막 토큰을 성으로 사용한다.
  ({String first, String last}) _formatDoublesName(String full) {
    final s = full.trim();
    if (s.isEmpty) return (first: '', last: '');
    final tokens = s.split(RegExp(r'\s+'));
    final upperTokens = <String>[];
    final otherTokens = <String>[];
    for (final t in tokens) {
      final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (letters.isNotEmpty && letters == letters.toUpperCase()) {
        upperTokens.add(t);
      } else {
        otherTokens.add(t);
      }
    }
    if (upperTokens.isNotEmpty && otherTokens.isNotEmpty) {
      return (
        first: otherTokens.join(' ').toUpperCase(),
        last: upperTokens.join(' ').toUpperCase(),
      );
    }
    // 폴백: 마지막 토큰을 성으로.
    if (tokens.length == 1) {
      return (first: '', last: tokens.first.toUpperCase());
    }
    return (
      first: tokens.sublist(0, tokens.length - 1).join(' ').toUpperCase(),
      last: tokens.last.toUpperCase(),
    );
  }

  Widget _avatarPlaceholder() {
    return Center(child: Icon(Icons.person, color: _subtleText, size: 30.sp));
  }

  /// 순위 변동 칩 — ▲상승(초록) / ▼하락(빨강) / –변동없음. null이면 빈 위젯.
  Widget _buildRankChange() {
    final change = player.rankChange;
    if (change == null) return const SizedBox.shrink();

    if (player.isRankSame) {
      return Text(
        '–',
        style: AppTypography.labelLg.copyWith(
          color: _subtleText,
          fontSize: 12.sp,
        ),
      );
    }

    final up = player.isRankUp;
    final color = up ? _upGreen : _downRed;
    final icon = up ? Icons.arrow_drop_up : Icons.arrow_drop_down;
    final magnitude = change.abs();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18.sp),
        Text(
          '$magnitude',
          style: AppTypography.labelLg.copyWith(color: color, fontSize: 12.sp),
        ),
      ],
    );
  }

  /// 포인트를 천 단위 콤마로 포맷 (정수부만). 없으면 빈 문자열.
  String _formatPoints(double? points) {
    if (points == null || points <= 0) return '';
    final s = points.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buf.write(',');
      }
    }
    return buf.toString();
  }
}
