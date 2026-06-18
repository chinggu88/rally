import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  static const Color _accent = AppColors.accent;
  static const Color _accentDark = AppColors.accentDark;
  static const Color _subtleText = AppColors.subtleText;

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
              SliverToBoxAdapter(child: SizedBox(height: 8.h)),
              SliverToBoxAdapter(child: _buildEventChips()),
              SliverToBoxAdapter(child: SizedBox(height: 12.h)),
              SliverToBoxAdapter(child: _buildStateArea(scheme)),
              SliverToBoxAdapter(child: SizedBox(height: 32.h)),
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
      title: Builder(builder: (_) {
        final name = (controller.tournamentName ?? '').trim();
        return Text(
          name.isEmpty ? '참가 선수' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 16.sp,
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
      height: 44.h,
      child: Obx(() {
        final selected = controller.selectedEvent;
        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          scrollDirection: Axis.horizontal,
          itemCount: TournamentParticipantsController.events.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
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
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 80.h),
          child: const Center(
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
              onPressed: controller.refreshParticipants,
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
          Icon(
            Icons.groups_outlined,
            size: 48.sp,
            color: _subtleText,
          ),
          SizedBox(height: 12.h),
          Text(
            '참가 선수 정보가 아직 공개되지 않았습니다.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
          SizedBox(height: 6.h),
          Obx(() => Text(
                '${TournamentParticipantsController.labelKoOf(controller.selectedEvent)}'
                ' 본선 발표 전이거나 데이터가 아직 동기화되지 않았어요.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: _subtleText,
                  fontSize: 13.sp,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildParticipantList(List<TournamentParticipantResponse> list) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in list) ...[
            _ParticipantCard(participant: p),
            SizedBox(height: 12.h),
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

/// 참가 선수 단일 카드 (매거진 스타일).
///
/// - 좌측: 시드 뱃지 (시드 없는 경우 "—") + 선수 사진(64x64)
/// - 중앙: 표시 이름(단식은 1명, 복식은 "p1 / p2") + 국기/국가코드
/// - 우측 하단: first_round 라벨 칩 (R64/R32/R16/QF/SF/F)
class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.participant});

  final TournamentParticipantResponse participant;

  static const Color _accent = AppColors.accent;
  static const Color _accentDark = AppColors.accentDark;
  static const Color _cardBg = AppColors.cardBg;
  static const Color _cardBorder = AppColors.cardBorder;
  static const Color _subtleText = AppColors.subtleText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
      child: participant.isDoubles ? _buildDoublesBody() : _buildSinglesBody(),
    );
  }

  Widget _buildSinglesBody() {
    final country = (participant.country ?? '').trim();
    final flag = flagEmoji(country);
    final firstRound = (participant.firstRound ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSeedBadge(participant.seed),
            SizedBox(width: 12.w),
            _buildAvatar(participant.photoUrl),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    participant.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineMd.copyWith(
                      color: Colors.white,
                      fontSize: 17.sp,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  _buildCountryRow(flag, country),
                ],
              ),
            ),
          ],
        ),
        if (firstRound.isNotEmpty) _buildFirstRoundFooter(firstRound),
      ],
    );
  }

  /// 복식 — PlayerView 복식 카드와 정합되는 2행 레이아웃.
  /// 좌측: 시드 배지(단식과 동일). 중앙: 두 선수 각각 한 줄.
  Widget _buildDoublesBody() {
    final country = (participant.country ?? '').trim();
    final flag = flagEmoji(country);
    final firstRound = (participant.firstRound ?? '').trim();
    final displayCountry = country.isEmpty ? '—' : country.toUpperCase();

    final p1 = _formatDoublesName(participant.player1Name);
    final p2 = _formatDoublesName(participant.player2Name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSeedBadge(participant.seed),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDoublesPlayerRow(
                    photoUrl: participant.photoUrl,
                    firstName: p1.first,
                    lastName: p1.last,
                    flag: flag,
                    country: displayCountry,
                  ),
                  SizedBox(height: 10.h),
                  _buildDoublesPlayerRow(
                    photoUrl: participant.photoUrl2,
                    firstName: p2.first,
                    lastName: p2.last,
                    flag: flag,
                    country: displayCountry,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (firstRound.isNotEmpty) _buildFirstRoundFooter(firstRound),
      ],
    );
  }

  /// 카드 하단 "시작 라운드" 행 — divider + 라벨 + 라운드 칩.
  Widget _buildFirstRoundFooter(String firstRound) {
    return Column(
      children: [
        SizedBox(height: 12.h),
        Divider(height: 1, color: _cardBorder.withValues(alpha: 0.8)),
        SizedBox(height: 10.h),
        Row(
          children: [
            Icon(
              Icons.flag_outlined,
              color: _subtleText,
              size: 14.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              '시작 라운드',
              style: AppTypography.labelLg.copyWith(
                color: _subtleText,
                fontSize: 11.sp,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            _buildRoundChip(firstRound),
          ],
        ),
      ],
    );
  }

  /// 복식 한 선수 행 — 원형 아바타 + first(small/muted) + LASTNAME(accent) + 국기/국가.
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
        _buildRoundAvatar(photoUrl, size: 36.r),
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

  Widget _buildRoundAvatar(String? photoUrl, {required double size}) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceAlt2,
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.4),
                placeholder: (_, __) => _avatarPlaceholder(),
                errorWidget: (_, __, ___) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  /// BWF 표기 "Dechapol PUAVARANUKROH" → first="DECHAPOL" / last="PUAVARANUKROH".
  /// 대문자 토큰을 성으로, 그 외를 이름으로 본다. 토큰 구분이 어려우면
  /// 마지막 토큰을 성으로 사용한다.
  ({String first, String last}) _formatDoublesName(String? full) {
    final s = (full ?? '').trim();
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
    if (tokens.length == 1) {
      return (first: '', last: tokens.first.toUpperCase());
    }
    return (
      first: tokens.sublist(0, tokens.length - 1).join(' ').toUpperCase(),
      last: tokens.last.toUpperCase(),
    );
  }

  /// 좌측 시드 뱃지 — 시드가 있으면 라임 옐로우 fill, 없으면 outline + "—"
  Widget _buildSeedBadge(int? seed) {
    final hasSeed = seed != null && seed > 0;
    final label = hasSeed ? '$seed' : '—';

    return Container(
      width: 36.w,
      height: 36.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasSeed ? _accent : Colors.transparent,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: hasSeed ? _accent : _cardBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: hasSeed ? 14.sp : 13.sp,
          letterSpacing: -0.2,
          color: hasSeed ? _accentDark : _subtleText,
        ),
      ),
    );
  }

  /// 선수 사진(64x64, cached_network_image) + 폴백 인물 아이콘.
  Widget _buildAvatar(String? photoUrl) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        width: 56.w,
        height: 56.h,
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
      color: AppColors.surfaceAlt2,
      alignment: Alignment.center,
      child: Icon(Icons.person, color: _subtleText, size: 26.sp),
    );
  }

  /// 국기 이모지 + 국가코드 (또는 폴백 칩).
  Widget _buildCountryRow(String flag, String country) {
    if (flag.isEmpty && country.isEmpty) {
      return Text(
        '국가 미정',
        style: AppTypography.labelLg.copyWith(
          color: _subtleText,
          fontSize: 12.sp,
        ),
      );
    }
    return Row(
      children: [
        if (flag.isNotEmpty)
          Text(
            flag,
            style: TextStyle(fontSize: 14.sp),
          )
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
            country.isEmpty ? '—' : country.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              color: _subtleText,
              fontSize: 12.sp,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: _accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        round.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 11.sp,
          letterSpacing: 0.6,
          color: _accent,
        ),
      ),
    );
  }
}
