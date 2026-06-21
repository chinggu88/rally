import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/profile_edit_controller.dart';

/// 프로필 편집 화면 — 아바타 변경/삭제 + 닉네임 편집.
class ProfileEditView extends GetView<ProfileEditController> {
  const ProfileEditView({super.key});

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
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '프로필 편집',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAvatar(),
              SizedBox(height: 32.h),
              _buildNicknameField(),
              SizedBox(height: 40.h),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Column(
        children: [
          Obx(() {
            final file = controller.pickedImage.value;
            final url = controller.currentAvatarUrl.value;
            ImageProvider? image;
            if (file != null) {
              image = FileImage(file);
            } else if (url != null && url.isNotEmpty) {
              image = CachedNetworkImageProvider(url);
            }
            return CircleAvatar(
              radius: 52.r,
              backgroundColor: _accent,
              backgroundImage: image,
              child: image == null
                  ? Icon(Icons.person, color: Colors.black, size: 52.sp)
                  : null,
            );
          }),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: controller.pickImage,
                icon: Icon(Icons.photo_library_outlined,
                    color: _accent, size: 18.sp),
                label: Text('사진 변경',
                    style: TextStyle(color: _accent, fontSize: 14.sp)),
              ),
              SizedBox(width: 8.w),
              TextButton.icon(
                onPressed: controller.removeAvatar,
                icon: Icon(Icons.delete_outline, color: _subtle, size: 18.sp),
                label: Text('삭제',
                    style: TextStyle(color: _subtle, fontSize: 14.sp)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text('닉네임',
              style: TextStyle(color: _subtle, fontSize: 13.sp)),
        ),
        TextField(
          controller: controller.nicknameController,
          maxLength: 20,
          style: TextStyle(color: Colors.white, fontSize: 15.sp),
          cursorColor: _accent,
          decoration: InputDecoration(
            hintText: '닉네임을 입력하세요',
            hintStyle: TextStyle(color: _subtle, fontSize: 15.sp),
            counterStyle: TextStyle(color: _subtle, fontSize: 11.sp),
            filled: true,
            fillColor: AppColors.cardBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: _divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: _accent, width: 1.4),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52.h,
      child: Obx(
        () => ElevatedButton(
          onPressed: controller.isSaving ? null : controller.save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.black,
            disabledBackgroundColor: _accent.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.r),
            ),
          ),
          child: controller.isSaving
              ? SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text('저장',
                  style:
                      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
