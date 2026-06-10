import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/player_detail_response.dart';
import '../controllers/player_controller.dart';
import '../controllers/player_detail_controller.dart';

/// 선수 상세 프로필(매거진) 화면 — Stitch: 선수 프로필 (매거진)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : b3ae5f6699f448e5bae6703091c35026
///
/// 리스트에서 받은 랭킹 컨텍스트(rank/이름/국가)로 히어로·퀵스탯을 그리고,
/// Edge Function `get-player`로 받은 `bwf_players` 상세를 하단 섹션에 병합한다.
/// 상세 데이터가 없으면(404) 컨텍스트만으로 표시하고 안내 배너를 노출한다.
class PlayerDetailView extends GetView<PlayerDetailController> {
  const PlayerDetailView({super.key});

  // Stitch 디자인 토큰 (AppColors와 정합되지 않는 시안 디테일만 별도 상수로 보존)
  static const Color _accent = Color(0xFFE0EC30); // secondary / neon green
  static const Color _subtleText = Color(0xFF9CA3A1);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Obx(() => _buildBody(context, scheme)),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back<void>(),
      ),
      title: Text(
        'Kinetic Court',
        style: TextStyle(
          color: _accent,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 18.sp,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme scheme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHero(context, scheme)),
        SliverToBoxAdapter(child: _buildQuickStats(scheme)),
        SliverToBoxAdapter(child: _buildContent(scheme)),
        SliverToBoxAdapter(child: SizedBox(height: 40.h)),
      ],
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context, ColorScheme scheme) {
    final media = MediaQuery.of(context);
    final heroHeight = (media.size.height * 0.56).clamp(380.0, 620.0);

    final detail = controller.detail;
    final name = _displayName(detail);
    final photoUrl = detail?.photoUrl;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildHeroImage(photoUrl, scheme),
          // 하단 → 배경색으로 페이드되는 그라데이션
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  scheme.surface,
                  scheme.surface.withValues(alpha: 0.0),
                ],
                stops: const [0.05, 0.6],
              ),
            ),
          ),
          // 헤드라인 오버레이
          Positioned(
            left: 20.w,
            right: 20.w,
            bottom: 24.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _heroLabel(),
                  style: AppTypography.labelLg.copyWith(
                    color: _accent,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 8.h),
                _buildHeroName(name),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(String? photoUrl, ColorScheme scheme) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return _buildHeroPlaceholder(scheme);
    }
    // 흑백 + 대비 강조 (매거진 톤)
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Image.network(
        photoUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildHeroPlaceholder(scheme);
        },
        errorBuilder: (context, error, stack) =>
            _buildHeroPlaceholder(scheme),
      ),
    );
  }

  Widget _buildHeroPlaceholder(ColorScheme scheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surfaceContainerHigh,
            scheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.sports_tennis,
          size: 96.sp,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.18),
        ),
      ),
    );
  }

  /// 큰 이탤릭 대문자 이름. 첫 단어는 흰색, 나머지는 네온 액센트.
  Widget _buildHeroName(String name) {
    final upper = name.toUpperCase();
    final spaceIdx = upper.indexOf(' ');
    final String head;
    final String tail;
    if (spaceIdx <= 0) {
      head = upper;
      tail = '';
    } else {
      head = upper.substring(0, spaceIdx);
      tail = upper.substring(spaceIdx + 1);
    }

    final baseStyle = AppTypography.displayLg.copyWith(
      color: Colors.white,
      fontSize: 52.sp,
      height: 1.02,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: head),
          if (tail.isNotEmpty) ...[
            const TextSpan(text: ' '),
            TextSpan(text: tail, style: const TextStyle(color: _accent)),
          ],
        ],
      ),
    );
  }

  // ── Quick Stats Bar ───────────────────────────────────────────────────

  Widget _buildQuickStats(ColorScheme scheme) {
    final detail = controller.detail;

    final rank = controller.rank;
    final rankLabel = rank != null ? '#$rank' : '—';
    final nationality = (detail?.countryName ??
            detail?.countryCode ??
            controller.fallbackCountryCode ??
            '—')
        .toUpperCase();
    final careerWins = detail?.careerWins?.toString() ?? '—';
    final style = (detail?.plays ?? detail?.handedness ?? '—').toUpperCase();

    final items = <Widget>[
      _StatBlock(label: 'World Rank', value: rankLabel, accent: true),
      _StatBlock(label: 'Nationality', value: nationality),
      _StatBlock(label: 'Career Wins', value: careerWins),
      _StatBlock(label: 'Playing Style', value: style),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              items[i],
              if (i != items.length - 1)
                Container(
                  width: 1.w,
                  height: 36.h,
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  color: scheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Content (state 분기) ──────────────────────────────────────────────

  Widget _buildContent(ColorScheme scheme) {
    if (controller.isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 64.h),
        child: const Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final error = controller.errorMessage;
    if (error != null) {
      return _buildErrorState(error, scheme);
    }

    final detail = controller.detail;
    final sections = <Widget>[];

    if (detail == null) {
      sections.add(_buildNotFoundBanner(scheme));
    } else {
      final vitals = _buildVitals(detail, scheme);
      if (vitals != null) sections.add(vitals);

      final career = _buildCareer(detail, scheme);
      if (career != null) sections.add(career);

      final bio = _buildBio(detail, scheme);
      if (bio != null) sections.add(bio);

      final link = _buildExternalLink(detail, scheme);
      if (link != null) sections.add(link);

      if (sections.isEmpty) {
        // 상세 행은 있으나 표시할 추가 필드가 없을 때
        sections.add(_buildNotFoundBanner(scheme));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections,
    );
  }

  Widget _buildErrorState(String message, ColorScheme scheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 48.h, 20.w, 48.h),
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
              onPressed: controller.refreshDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: scheme.onSecondary,
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

  Widget _buildNotFoundBanner(ColorScheme scheme) {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 0),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: _subtleText, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상세 프로필 준비 중',
                  style: AppTypography.labelLg.copyWith(color: Colors.white),
                ),
                SizedBox(height: 4.h),
                Text(
                  '이 선수의 상세 데이터가 아직 등록되지 않았습니다.',
                  style: AppTypography.bodyMd.copyWith(color: _subtleText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile / Vitals ──────────────────────────────────────────────────

  Widget? _buildVitals(PlayerDetailResponse d, ColorScheme scheme) {
    final rows = <Widget>[];

    final born = _bornText(d);
    if (born != null) rows.add(_VitalRow(label: 'Born', value: born));
    if (_has(d.birthplace)) {
      rows.add(_VitalRow(label: 'Birthplace', value: d.birthplace!.trim()));
    }
    if (d.heightCm != null) {
      rows.add(_VitalRow(label: 'Height', value: '${d.heightCm} cm'));
    }
    if (_has(d.handedness)) {
      rows.add(_VitalRow(label: 'Handedness', value: d.handedness!.trim()));
    }
    if (_has(d.plays)) {
      rows.add(_VitalRow(label: 'Plays', value: d.plays!.trim()));
    }
    if (_has(d.coach)) {
      rows.add(_VitalRow(label: 'Coach', value: d.coach!.trim()));
    }

    if (rows.isEmpty) return null;

    return _Section(
      title: 'Profile',
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i != rows.length - 1)
                Divider(height: 1, color: scheme.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }

  // ── Career ────────────────────────────────────────────────────────────

  Widget? _buildCareer(PlayerDetailResponse d, ColorScheme scheme) {
    final tiles = <Widget>[];
    if (d.careerTitles != null) {
      tiles.add(_CareerTile(label: 'Titles', value: '${d.careerTitles}'));
    }
    if (d.careerWins != null) {
      tiles.add(_CareerTile(label: 'Wins', value: '${d.careerWins}'));
    }
    if (d.careerLosses != null) {
      tiles.add(_CareerTile(label: 'Losses', value: '${d.careerLosses}'));
    }
    if (tiles.isEmpty) return null;

    return _Section(
      title: 'Career',
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) SizedBox(width: 12.w),
          ],
        ],
      ),
    );
  }

  // ── Pro Spotlight (bio) ───────────────────────────────────────────────

  Widget? _buildBio(PlayerDetailResponse d, ColorScheme scheme) {
    if (!_has(d.bio)) return null;
    final paragraphs = d.bio!
        .trim()
        .split(RegExp(r'\n{2,}|\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return null;

    return _Section(
      title: 'Pro Spotlight',
      overline: 'Editorial',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i == 0)
              _buildDropCapParagraph(paragraphs[i])
            else
              Text(
                paragraphs[i].trim(),
                style: AppTypography.bodyLg.copyWith(color: scheme.onSurface),
              ),
            if (i != paragraphs.length - 1) SizedBox(height: 16.h),
          ],
        ],
      ),
    );
  }

  /// 첫 글자를 키운 의사(疑似) 드롭캡 문단.
  Widget _buildDropCapParagraph(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    final first = trimmed.substring(0, 1);
    final rest = trimmed.substring(1);

    return RichText(
      text: TextSpan(
        style: AppTypography.bodyLg.copyWith(color: AppColors.dark.onSurface),
        children: [
          TextSpan(
            text: first,
            style: TextStyle(
              fontFamily: AppTypography.chivo,
              fontWeight: FontWeight.w800,
              fontSize: 40.sp,
              height: 1.0,
              color: _accent,
            ),
          ),
          TextSpan(text: rest),
        ],
      ),
    );
  }

  // ── External link ─────────────────────────────────────────────────────

  Widget? _buildExternalLink(PlayerDetailResponse d, ColorScheme scheme) {
    if (!_has(d.detailUrl)) return null;
    return _Section(
      title: 'More',
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ListTile(
          leading: const Icon(Icons.open_in_new, color: _accent),
          title: Text(
            'BWF 공식 프로필',
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
          subtitle: Text(
            d.detailUrl!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd.copyWith(
              color: _subtleText,
              fontSize: 13.sp,
            ),
          ),
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────

  String _displayName(PlayerDetailResponse? detail) {
    final fromDetail = detail?.nameDisplay?.trim();
    if (fromDetail != null && fromDetail.isNotEmpty) return fromDetail;
    final fallback = controller.fallbackName?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return '—';
  }

  String _heroLabel() {
    final rank = controller.rank;
    if (rank == 1) return 'World Number One';
    if (rank != null) return 'World Rank #$rank';
    final category = controller.category;
    if (category != null && category.isNotEmpty) {
      return PlayerController.labelEnOf(category);
    }
    return 'Player Profile';
  }

  String? _bornText(PlayerDetailResponse d) {
    final date = _has(d.birthday) ? d.birthday!.trim() : null;
    final age = d.age;
    if (date == null && age == null) return null;
    if (date != null && age != null) return '$date (만 $age세)';
    if (date != null) return date;
    return '만 $age세';
  }

  bool _has(String? s) => s != null && s.trim().isNotEmpty;
}

/// 퀵스탯 단일 블록 (라벨 + 값)
class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  static const Color _accent = Color(0xFFE0EC30);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelLg.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 11.sp,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: AppTypography.statsNumber.copyWith(
            color: accent ? _accent : Colors.white,
          ),
        ),
      ],
    );
  }
}

/// 프로필 정보 행 (라벨 — 값)
class _VitalRow extends StatelessWidget {
  const _VitalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              label.toUpperCase(),
              style: AppTypography.labelLg.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 12.sp,
                letterSpacing: 0.6,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMd.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// 통산 성적 타일 (값 + 라벨)
class _CareerTile extends StatelessWidget {
  const _CareerTile({required this.label, required this.value});

  final String label;
  final String value;

  static const Color _accent = Color(0xFFE0EC30);

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.headlineLg.copyWith(color: _accent),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label.toUpperCase(),
            style: AppTypography.labelLg.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11.sp,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// 섹션 래퍼 (오버라인 + 타이틀 + 본문)
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.overline,
  });

  final String title;
  final String? overline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (overline != null) ...[
                Text(
                  overline!.toUpperCase(),
                  style: AppTypography.labelLg.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              Text(
                title.toUpperCase(),
                style: AppTypography.headlineLg.copyWith(color: Colors.white),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(height: 1.h, color: scheme.outlineVariant),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          child,
        ],
      ),
    );
  }
}
