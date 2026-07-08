import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';

/// 홈 화면 초기 로딩 스켈레톤.
///
/// 실제 홈 레이아웃(남은 대회 칩 → 라이브 매치 카드 → 오늘 경기 → 뉴스)과
/// 동일한 구조/크기로 뼈대를 그려, 로딩 완료 시 화면 전환이 자연스럽다.
/// 전체가 부드럽게 깜빡이는 펄스 애니메이션으로 로딩 중임을 표현한다.
class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          _buildTournamentChips(),
          SizedBox(height: 24.h),
          _buildSectionHeader(withDot: true),
          SizedBox(height: 10.h),
          _buildLiveCard(context),
          SizedBox(height: 24.h),
          _buildSectionHeader(withDot: true),
          SizedBox(height: 12.h),
          _buildTodayCards(),
          SizedBox(height: 24.h),
          _buildSectionHeader(withDot: false),
          SizedBox(height: 12.h),
          _buildNewsCards(),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  /// 스켈레톤 뼈대(bone) 공통 블록.
  Widget _bone({
    required double width,
    required double height,
    double? radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius ?? 8.r),
      ),
    );
  }

  /// 카드 배경(실제 카드와 동일한 톤).
  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(16.r),
    border: Border.all(color: AppColors.cardBorder),
  );

  // ── 남은 대회 칩 ────────────────────────────────────────
  Widget _buildTournamentChips() {
    return SizedBox(
      height: 44.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _chip(150.w),
          SizedBox(width: 10.w),
          _chip(120.w),
          SizedBox(width: 10.w),
          _chip(140.w),
        ],
      ),
    );
  }

  Widget _chip(double width) {
    return Center(
      child: Container(
        width: width,
        height: 36.h,
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: AppColors.cardBorder),
        ),
      ),
    );
  }

  // ── 섹션 헤더 (도트 + 타이틀 바) ─────────────────────────
  Widget _buildSectionHeader({required bool withDot}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
      child: Row(
        children: [
          if (withDot) ...[
            Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                color: AppColors.inactive,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8.w),
          ],
          _bone(width: 92.w, height: 18.h, radius: 4.r),
        ],
      ),
    );
  }

  // ── 라이브 매치 카드 ────────────────────────────────────
  Widget _buildLiveCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.85).clamp(280.0, 360.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(16.w),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 대회명 / 라운드
            _bone(width: 180.w, height: 12.h, radius: 4.r),
            SizedBox(height: 8.h),
            _bone(width: 120.w, height: 10.h, radius: 4.r),
            SizedBox(height: 20.h),
            // 팀1 vs 팀2
            _buildTeamRow(),
            SizedBox(height: 14.h),
            _buildTeamRow(),
            SizedBox(height: 20.h),
            // 하단 스코어 바
            _bone(width: double.infinity, height: 40.h, radius: 10.r),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow() {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(child: _bone(width: double.infinity, height: 12.h)),
        SizedBox(width: 24.w),
        _bone(width: 28.w, height: 20.h, radius: 6.r),
      ],
    );
  }

  // ── 오늘 경기 카드 ──────────────────────────────────────
  Widget _buildTodayCards() {
    return SizedBox(
      height: 118.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        physics: const NeverScrollableScrollPhysics(),
        children: [_todayCard(), SizedBox(width: 10.w), _todayCard()],
      ),
    );
  }

  Widget _todayCard() {
    return Container(
      width: 310.w,
      padding: EdgeInsets.all(14.w),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bone(width: 140.w, height: 10.h, radius: 4.r),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _bone(width: double.infinity, height: 12.h)),
              SizedBox(width: 20.w),
              _bone(width: 24.w, height: 16.h, radius: 4.r),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(child: _bone(width: double.infinity, height: 12.h)),
              SizedBox(width: 20.w),
              _bone(width: 24.w, height: 16.h, radius: 4.r),
            ],
          ),
        ],
      ),
    );
  }

  // ── 뉴스 카드 ───────────────────────────────────────────
  Widget _buildNewsCards() {
    final cardWidth = 310.w;
    final cardHeight = cardWidth * 16 / 9;

    return SizedBox(
      height: cardHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _newsCard(cardWidth, cardHeight),
          SizedBox(width: 10.w),
          _newsCard(cardWidth, cardHeight),
        ],
      ),
    );
  }

  Widget _newsCard(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: _cardDecoration,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _bone(width: width * 0.75, height: 16.h, radius: 4.r),
            SizedBox(height: 10.h),
            _bone(width: width * 0.5, height: 12.h, radius: 4.r),
          ],
        ),
      ),
    );
  }
}
