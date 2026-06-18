import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/my_info_controller.dart';

/// 내 정보 (비로그인 상태) — Stitch: 내 정보 (매거진)
///
/// Stitch projectId: 307006344264476289
/// Stitch screenId : 8329646c315c48fdb5bfa15f9a643418
class MyInfoView extends GetView<MyInfoController> {
  const MyInfoView({super.key});

  // --- Design tokens (다크 + 라임 옐로우 테마) ---
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _accent = Color(0xFFD7FF00);
  static const Color _subtle = Color(0xFF9CA3A1);
  static const Color _divider = Color(0xFF1F2421);

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
      _buildSettingsSection(),
    ];
  }

  List<Widget> _buildLoggedInChildren() {
    return [
      _buildProfileCard(),
      SizedBox(height: 24.h),
      _buildLogoutCta(),
      SizedBox(height: 28.h),
      _buildSettingsSection(),
    ];
  }

  Widget _buildProfileCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1F1C), Color(0xFF0A0A0A)],
        ),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: _accent,
            child: Icon(Icons.person, color: Colors.black, size: 28.sp),
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
                  controller.email ?? '-',
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
          colors: [Color(0xFF1B1F1C), Color(0xFF0A0A0A)],
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

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _buildLockedRow('Profile Settings'),
        _buildLockedRow('Notification Settings'),
        _buildLockedRow('Club Management'),
        _buildLockedRow('Customer Support'),
      ],
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
