import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/my_info_controller.dart';

/// 내 정보 (마이페이지) — Stitch: 내 정보 (매거진)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : 8329646c315c48fdb5bfa15f9a643418
class MyInfoView extends GetView<MyInfoController> {
  const MyInfoView({super.key});

  // --- Design tokens (다크 + 라임 옐로우 테마) ---
  static const Color _bg = AppColors.bg;
  static const Color _accent = AppColors.accentLime;
  static const Color _subtle = AppColors.subtleText;
  static const Color _divider = AppColors.divider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Rally',
          style: TextStyle(
            color: _accent,
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(
          () => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: controller.isLoggedIn
                  ? _buildLoggedInChildren()
                  : _buildAnonymousChildren(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnonymousChildren() {
    return [
      _buildHeroBanner(),
      SizedBox(height: 24.h),
      _buildLoginCta(),
      SizedBox(height: 12.h),
      _buildSignUpCta(),
      SizedBox(height: 28.h),
      _buildLockedSettingsSection(),
    ];
  }

  List<Widget> _buildLoggedInChildren() {
    return [
      _buildProfileCard(),
      SizedBox(height: 24.h),
      _buildLoggedInSettingsSection(),
      SizedBox(height: 24.h),
      _buildLogoutCta(),
    ];
  }

  Widget _buildProfileCard() {
    final avatarUrl = controller.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final title = (controller.nickname?.isNotEmpty ?? false)
        ? controller.nickname!
        : (controller.email ?? '-');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.gradientStart, AppColors.bg],
        ),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: _accent,
            backgroundImage:
                hasAvatar ? CachedNetworkImageProvider(avatarUrl) : null,
            child: hasAvatar
                ? null
                : Icon(Icons.person, color: Colors.black, size: 28.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '환영합니다',
                  style: TextStyle(color: _subtle, fontSize: 12.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.goToProfileEdit,
            icon: Icon(Icons.edit_outlined, color: _accent, size: 20.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCta() {
    return SizedBox(
      height: 52.h,
      child: OutlinedButton(
        onPressed: controller.signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _accent, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.r),
          ),
        ),
        child: Text(
          '로그아웃',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 220.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.gradientStart, AppColors.bg],
        ),
        border: Border.all(color: _divider),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '당신만의 코트가\n기다리고 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '로그인하여 프리미엄 기사와\n대회 소식을 만나보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _subtle,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCta() {
    return SizedBox(
      height: 52.h,
      child: ElevatedButton(
        onPressed: controller.goToLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.r),
          ),
        ),
        child: Text(
          '로그인',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildSignUpCta() {
    return SizedBox(
      height: 52.h,
      child: OutlinedButton(
        onPressed: controller.goToSignUp,
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _accent, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.r),
          ),
        ),
        child: Text(
          '회원가입',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // ── 로그인 상태: 실제 동작하는 설정 메뉴 ──────────────────────────────

  Widget _buildLoggedInSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Settings'),
        _buildMenuRow('프로필 편집', onTap: controller.goToProfileEdit),
        _buildSwitchRow(
          '알림 설정',
          value: controller.notificationsEnabled,
          onChanged: controller.toggleNotifications,
        ),
        _buildMenuRow('좋아하는 선수', onTap: controller.goToFavoritePlayers),
        _buildMenuRow(
          '회원탈퇴',
          onTap: controller.confirmDeleteAccount,
          danger: true,
        ),
      ],
    );
  }

  // ── 비로그인 상태: 잠긴 설정 메뉴 ──────────────────────────────────
  Widget _buildLockedSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Settings'),
        _buildLockedRow('Profile Settings'),
        _buildLockedRow('Notification Settings'),
        _buildLockedRow('Club Management'),
        _buildLockedRow('Customer Support'),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMenuRow(
    String label, {
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
        decoration: const Border(
          bottom: BorderSide(color: _divider, width: 0.6),
        ).toBoxDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: danger ? AppColors.liveRed : Colors.white,
                  fontSize: 14.sp,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: danger ? AppColors.liveRed : _subtle,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
      decoration: const Border(
        bottom: BorderSide(color: _divider, width: 0.6),
      ).toBoxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
            activeTrackColor: _accent,
            inactiveThumbColor: _subtle,
            inactiveTrackColor: AppColors.cardBg,
          ),
        ],
      ),
    );
  }

  Widget _buildLockedRow(String label) {
    return InkWell(
      onTap: controller.goToLogin,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 4.w),
        decoration: const Border(
          bottom: BorderSide(color: _divider, width: 0.6),
        ).toBoxDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ),
            Icon(Icons.lock_outline, color: _subtle, size: 18.sp),
          ],
        ),
      ),
    );
  }
}

extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
