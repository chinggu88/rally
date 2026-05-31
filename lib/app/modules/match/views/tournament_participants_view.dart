import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/tournament_participant_response.dart';
import '../../../utils/country_flag.dart';
import '../controllers/tournament_participants_controller.dart';

/// 대회 참가 선수 화면 — 종목 탭 기반.
///
/// 대회 상세 화면의 "대진표 보기" CTA로 진입한다.
/// 상단 가로 종목 칩(MS/WS/MD/WD/XD)을 선택하면 해당 종목의 참가 선수가
/// 매거진 카드 리스트로 노출된다. Pull-to-refresh 지원.
///
/// 디자인 토큰은 [TournamentDetailView] / [PlayerView]와 정합되며,
/// 라임 옐로우 `#C3F400`을 액센트로 사용한다.
class TournamentParticipantsView
    extends GetView<TournamentParticipantsController> {
  const TournamentParticipantsView({super.key});

  // 매거진 디자인 토큰 (AppColors와 정합되지 않는 시안 디테일만 별도 상수).
  // 카드/칩 토큰은 내부 위젯(`_EventChip`, `_ParticipantCard`)에서 자체 보존한다.
  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: controller.refreshParticipants,
          color: _accent,
          backgroundColor: scheme.surfaceContainer,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(child: _buildEventChips()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildStateArea(scheme)),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
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
      title: Obx(() {
        final name = (controller.tournamentName ?? '').trim();
        return Text(
          name.isEmpty ? '참가 선수' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        );
      }),
      centerTitle: true,
    );
  }

  // ── 종목 칩 ──────────────────────────────────────────────────────────

  /// 종목 선택 칩 행 (MS / WS / MD / WD / XD — 가로 스크롤 가능)
  Widget _buildEventChips() {
    return SizedBox(
      height: 44,
      child: Obx(() {
        final selected = controller.selectedEvent;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: TournamentParticipantsController.events.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final code = TournamentParticipantsController.events[index];
            final isSelected = code == selected;
            return _EventChip(
              code: code,
              koLabel: TournamentParticipantsController.labelKoOf(code),
              selected: isSelected,
              onTap: () => controller.changeEvent(code),
            );
          },
        );
      }),
    );
  }

  // ── 상태 분기 (로딩 / 에러 / 빈 / 정상 리스트) ───────────────────────

  Widget _buildStateArea(ColorScheme scheme) {
    return Obx(() {
      if (controller.isLoading && controller.participants.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: CircularProgressIndicator(color: _accent),
          ),
        );
      }

      final error = controller.errorMessage;
      if (error != null && controller.participants.isEmpty) {
        return _buildErrorState(error);
      }

      if (controller.participants.isEmpty) {
        return _buildEmptyState();
      }

      return _buildParticipantList(controller.participants);
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
              onPressed: controller.refreshParticipants,
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
          Text(
            '참가 선수 정보가 아직 공개되지 않았습니다.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Obx(() => Text(
                '${TournamentParticipantsController.labelKoOf(controller.selectedEvent)}'
                ' 본선 발표 전이거나 데이터가 아직 동기화되지 않았어요.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: _subtleText,
                  fontSize: 13,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildParticipantList(List<TournamentParticipantResponse> list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in list) ...[
            _ParticipantCard(participant: p),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// 종목 선택 칩 (선택 시 라임 옐로우 fill — `PlayerView`의 `_CategoryChip`과 정합)
class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.code,
    required this.koLabel,
    required this.selected,
    required this.onTap,
  });

  final String code;
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

/// 참가 선수 단일 카드 (매거진 스타일).
///
/// - 좌측: 시드 뱃지 (시드 없는 경우 "—") + 선수 사진(64x64)
/// - 중앙: 표시 이름(단식은 1명, 복식은 "p1 / p2") + 국기/국가코드
/// - 우측 하단: first_round 라벨 칩 (R64/R32/R16/QF/SF/F)
class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.participant});

  final TournamentParticipantResponse participant;

  static const Color _accent = Color(0xFFC3F400);
  static const Color _accentDark = Color(0xFF283500);
  static const Color _cardBg = Color(0xFF1C1B1B);
  static const Color _cardBorder = Color(0xFF2A2A2A);
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final country = (participant.country ?? '').trim();
    final flag = flagEmoji(country);
    final firstRound = (participant.firstRound ?? '').trim();
    final isDoubles = participant.isDoubles;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSeedBadge(participant.seed),
              const SizedBox(width: 12),
              _buildAvatar(participant.photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDoubles)
                      _buildDoublesNames(
                        participant.player1Name,
                        participant.player2Name,
                      )
                    else
                      Text(
                        participant.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMd.copyWith(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.2,
                        ),
                      ),
                    const SizedBox(height: 6),
                    _buildCountryRow(flag, country),
                  ],
                ),
              ),
            ],
          ),
          if (firstRound.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: _cardBorder.withValues(alpha: 0.8)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: _subtleText,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '시작 라운드',
                  style: AppTypography.labelLg.copyWith(
                    color: _subtleText,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                _buildRoundChip(firstRound),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 좌측 시드 뱃지 — 시드가 있으면 라임 옐로우 fill, 없으면 outline + "—"
  Widget _buildSeedBadge(int? seed) {
    final hasSeed = seed != null && seed > 0;
    final label = hasSeed ? '$seed' : '—';

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasSeed ? _accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasSeed ? _accent : _cardBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: hasSeed ? 14 : 13,
          letterSpacing: -0.2,
          color: hasSeed ? _accentDark : _subtleText,
        ),
      ),
    );
  }

  /// 선수 사진(64x64, cached_network_image) + 폴백 인물 아이콘.
  Widget _buildAvatar(String? photoUrl) {
    const double size = 56;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _avatarPlaceholder(),
                errorWidget: (_, __, ___) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFF252423),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: _subtleText, size: 26),
    );
  }

  /// 복식 — 두 선수를 한 줄씩 표시 ("/" 구분이 아닌 명확한 2행).
  Widget _buildDoublesNames(String? p1, String? p2) {
    final left = (p1 ?? '').trim().isEmpty ? '—' : p1!.trim();
    final right = (p2 ?? '').trim().isEmpty ? '—' : p2!.trim();

    final nameStyle = AppTypography.headlineMd.copyWith(
      color: Colors.white,
      fontSize: 15,
      height: 1.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        const SizedBox(height: 2),
        Text(
          right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }

  /// 국기 이모지 + 국가코드 (또는 폴백 칩).
  Widget _buildCountryRow(String flag, String country) {
    if (flag.isEmpty && country.isEmpty) {
      return Text(
        '국가 미정',
        style: AppTypography.labelLg.copyWith(
          color: _subtleText,
          fontSize: 12,
        ),
      );
    }
    return Row(
      children: [
        if (flag.isNotEmpty)
          Text(
            flag,
            style: const TextStyle(fontSize: 14),
          )
        else
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
        Flexible(
          child: Text(
            country.isEmpty ? '—' : country.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              color: _subtleText,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  /// 라운드 칩 (R64/R32/R16/QF/SF/F) — 라임 옐로우 outline + 검정 텍스트(accent).
  Widget _buildRoundChip(String round) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        round.toUpperCase(),
        style: const TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.6,
          color: _accent,
        ),
      ),
    );
  }
}
