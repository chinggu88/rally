import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/player_response.dart';
import '../controllers/player_controller.dart';

/// 선수 화면 — Stitch: 선수 리스트 (매거진)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : eeae55cab3614d408743636d325e3b88
class PlayerView extends GetView<PlayerController> {
  const PlayerView({super.key});

  // Stitch 디자인 토큰 (AppColors와 정합되지 않는 시안 디테일만 별도 상수로 보존)
  static const Color _accent = Color(0xFFC3F400); // primaryContainer / secondary 톤
  static const Color _accentDark = Color(0xFF283500); // onPrimary on accent
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshPlayers,
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: _buildStateArea(scheme)),
      ],
    );
  }

  /// 상단 헤더 ("Players to Watch" + 부제) — Stitch 디자인 그대로
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Players to Watch',
            style: AppTypography.headlineLg.copyWith(
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '세계 최정상 BWF 랭킹 선수들의 파워, 정밀함, 민첩성을 만나보세요.',
            style: AppTypography.bodyMd.copyWith(
              color: _subtleText,
            ),
          ),
        ],
      ),
    );
  }

  /// 카테고리 칩 그룹 (MS / WS / MD / WD / XD — 가로 스크롤 가능)
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: Obx(() {
        final selected = controller.selectedCategory;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: PlayerController.categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
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

  /// 상태 분기 영역 (로딩 / 에러 / 빈 / 정상 목록)
  Widget _buildStateArea(ColorScheme scheme) {
    return Obx(() {
      if (controller.isLoading && controller.players.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: CircularProgressIndicator(color: _accent),
          ),
        );
      }

      final error = controller.errorMessage;
      if (error != null && controller.players.isEmpty) {
        return _buildErrorState(error);
      }

      if (controller.players.isEmpty) {
        return _buildEmptyState();
      }

      return _buildPlayerList(controller.players);
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
              onPressed: controller.refreshPlayers,
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
            Icons.groups_outlined,
            size: 48,
            color: _subtleText,
          ),
          const SizedBox(height: 12),
          Obx(() => Text(
                '${PlayerController.labelKoOf(controller.selectedCategory)} '
                '랭킹 데이터가 없습니다.',
                style: AppTypography.bodyMd.copyWith(color: Colors.white),
              )),
          const SizedBox(height: 6),
          Text(
            '다른 종목을 선택해보세요.',
            style: AppTypography.bodyMd.copyWith(color: _subtleText),
          ),
        ],
      ),
    );
  }

  /// 선수 카드 리스트 (rank 오름차순)
  Widget _buildPlayerList(List<PlayerResponse> list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in list) ...[
            _PlayerCard(
              player: p,
              categoryLabel: PlayerController.labelEnOf(
                controller.selectedCategory,
              ),
              onTap: () => controller.openPlayerDetail(p),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
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

  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _chipBg = Color(0xFF201F1F);
  static const Color _chipBorder = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _accent : _chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _accent : _chipBorder,
            ),
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
                  fontSize: 12,
                  letterSpacing: 0.6,
                  color: selected ? _accentDark : _accent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                koLabel,
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
/// - 좌측: 큰 랭킹 숫자 (`#1` 형식, 라임 옐로우 액센트)
/// - 중앙: 카테고리 라벨 + 선수명 + 국가 코드
/// - 우측: 화살표 (탭 진입 affordance)
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.categoryLabel,
    required this.onTap,
  });

  final PlayerResponse player;
  final String categoryLabel;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _cardBg = Color(0xFF1C1B1B);
  static const Color _cardBorder = Color(0xFF2A2A2A);
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final rank = player.rank;
    final name = (player.playerName ?? '').trim();
    final country = (player.countryCode ?? '').trim();
    final displayName = name.isEmpty ? '—' : name;
    final displayCountry = country.isEmpty ? '—' : country.toUpperCase();
    final rankLabel = rank != null ? '#$rank' : '#—';

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 좌측: 큰 랭킹 숫자 (라임 옐로우 액센트)
              _buildRankBlock(rankLabel),
              const SizedBox(width: 16),
              // 중앙: 카테고리 + 이름 + 국가
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1행: 카테고리 라벨 (Stitch 톤 — 라임 옐로우 uppercase)
                    Text(
                      categoryLabel.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLg.copyWith(
                        color: _accent,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 2행: 선수명 (큰 폰트, 2줄 ellipsis)
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 3행: 국가 코드
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF353534),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.flag_outlined,
                            color: _subtleText,
                            size: 10,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayCountry,
                          style: AppTypography.labelLg.copyWith(
                            color: _subtleText,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 우측: 진입 화살표
              const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBlock(String rankLabel) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          rankLabel,
          style: const TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1.0,
            letterSpacing: -0.5,
            color: _accentDark,
          ),
        ),
      ),
    );
  }
}
