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
  static const Color _menuCardBg = AppColors.cardBg;

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
            child: const Icon(Icons.notifications_none, color: Colors.white),
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
      _buildLockedMenuCard(),
    ];
  }

  List<Widget> _buildLoggedInChildren() {
    return [
      _buildProfileHeader(),
      SizedBox(height: 24.h),
      _buildEditProfileButton(),
      SizedBox(height: 28.h),
      _buildMenuCard(),
      SizedBox(height: 24.h),
      _buildLogoutCta(),
    ];
  }

  // ── 로그인 상태: 상단 프로필 헤더 ────────────────────────────────────
  Widget _buildProfileHeader() {
    final avatarUrl = controller.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final title = (controller.nickname?.isNotEmpty ?? false)
        ? controller.nickname!
        : (controller.email?.split('@').first ?? 'RALLY');
    final subtitle = controller.email ?? '-';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6.h),
              Text(
                subtitle,
                style: TextStyle(
                  color: _subtle,
                  fontSize: 13.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(width: 16.w),
        _buildAvatarFrame(hasAvatar: hasAvatar, avatarUrl: avatarUrl),
      ],
    );
  }

  Widget _buildAvatarFrame({required bool hasAvatar, String? avatarUrl}) {
    return Container(
      width: 88.w,
      height: 88.w,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _accent, width: 2.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.r),
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.cardBg),
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.cardBg),
              )
            : Container(
                color: AppColors.cardBg,
                alignment: Alignment.center,
                child: Icon(Icons.person, color: _accent, size: 36.sp),
              ),
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return SizedBox(
      height: 52.h,
      child: OutlinedButton(
        onPressed: controller.goToProfileEdit,
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent, width: 1.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          '프로필 편집',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  // ── 메뉴 카드 (이미지의 5개 항목) ─────────────────────────────────
  Widget _buildMenuCard() {
    final items = <_MenuItemData>[
      _MenuItemData(
        icon: Icons.calendar_today_rounded,
        title: '알림 설정',
        subtitle: '앱 알림을 관리하세요',
        onTap: () =>
            controller.toggleNotifications(!controller.notificationsEnabled),
        trailing: Obx(
          () => Switch(
            value: controller.notificationsEnabled,
            onChanged: controller.toggleNotifications,
            activeThumbColor: Colors.black,
            activeTrackColor: _accent,
            inactiveThumbColor: _subtle,
            inactiveTrackColor: AppColors.surfaceAlt,
          ),
        ),
      ),
      _MenuItemData(
        icon: Icons.share_outlined,
        title: '친구 초대',
        onTap: controller.goToInviteFriends,
      ),
      _MenuItemData(
        icon: Icons.workspace_premium_outlined,
        title: '좋아하는 선수',
        subtitle: '관심 선수를 등록하고 소식을 받아보세요',
        onTap: controller.goToFavoritePlayers,
      ),
      _MenuItemData(
        icon: Icons.help_outline,
        title: '도움말',
        onTap: controller.goToHelp,
      ),
      _MenuItemData(
        icon: Icons.chat_bubble_outline,
        title: '피드백 보내기',
        onTap: controller.goToFeedback,
      ),
      _MenuItemData(
        icon: Icons.person_remove_outlined,
        title: '회원탈퇴',
        onTap: controller.confirmDeleteAccount,
        danger: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _menuCardBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _buildMenuItem(items[i]),
            if (i != items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: const Divider(
                  color: _divider,
                  height: 1,
                  thickness: 0.6,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItemData item) {
    final color = item.danger ? AppColors.liveRed : Colors.white;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            _buildIconBox(item.icon, danger: item.danger),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        color: _subtle,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            item.trailing ??
                Icon(
                  Icons.chevron_right,
                  color: item.danger ? AppColors.liveRed : _subtle,
                  size: 22.sp,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, {bool danger = false}) {
    return Container(
      width: 42.w,
      height: 42.w,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12.r),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: danger ? AppColors.liveRed : _accent,
        size: 20.sp,
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

  // ── 비로그인 상태 ────────────────────────────────────────────────
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

  Widget _buildLockedMenuCard() {
    final items = <_MenuItemData>[
      _MenuItemData(
        icon: Icons.calendar_today_rounded,
        title: '알림 설정',
        onTap: controller.goToLogin,
        locked: true,
      ),
      _MenuItemData(
        icon: Icons.share_outlined,
        title: '친구 초대',
        onTap: controller.goToLogin,
        locked: true,
      ),
      _MenuItemData(
        icon: Icons.workspace_premium_outlined,
        title: '좋아하는 선수',
        onTap: controller.goToLogin,
        locked: true,
      ),
      _MenuItemData(
        icon: Icons.help_outline,
        title: '도움말',
        onTap: controller.goToLogin,
        locked: true,
      ),
      _MenuItemData(
        icon: Icons.chat_bubble_outline,
        title: '피드백 보내기',
        onTap: controller.goToLogin,
        locked: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _menuCardBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _buildMenuItem(items[i].copyWithLockedTrailing(_subtle)),
            if (i != items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: const Divider(
                  color: _divider,
                  height: 1,
                  thickness: 0.6,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItemData {
  _MenuItemData({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.danger = false,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;
  final bool locked;

  _MenuItemData copyWithLockedTrailing(Color color) {
    return _MenuItemData(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      danger: danger,
      locked: locked,
      trailing: Icon(Icons.lock_outline, color: color, size: 18),
    );
  }
}
