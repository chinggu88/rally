import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../controllers/community_compose_controller.dart';
import '../controllers/community_controller.dart';

/// 커뮤니티 글 작성 / 수정 화면 (기획서 S-3).
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `SignUpView` 의 입력 폼
/// 스타일과 `CommunityView` 의 칩 톤을 준용했다.
///
/// `Obx` 는 카테고리 칩 / 글자수 카운터 / 이미지 바 / 등록 버튼으로 쪼갠다.
/// 화면 전체를 하나로 감싸면 한 글자 칠 때마다 본문 필드까지 다시 그린다.
class CommunityComposeView extends GetView<CommunityComposeController> {
  const CommunityComposeView({super.key});

  /// 게시 가능한 카테고리 — 목록의 "전체"(null)는 제외한다.
  static final List<String> _writableCategories =
      CommunityController.categories.whereType<String>().toList();

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return PopScope(
      // 작성 중이면 시스템 뒤로가기도 확인 다이얼로그를 거치게 한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(scheme),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            top: false,
            child: Obx(() {
              if (controller.isLoadingPost.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }
              final error = controller.loadError.value;
              if (error != null) return _buildLoadError(error);
              return _buildForm();
            }),
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        tooltip: '닫기',
        onPressed: _handleBack,
      ),
      title: Text(
        controller.isEditMode ? '글 수정' : '글쓰기',
        style: TextStyle(
          color: Colors.white,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 16.sp,
          letterSpacing: 0.2,
        ),
      ),
      actions: [_buildSubmitAction()],
    );
  }

  Widget _buildSubmitAction() {
    return Obx(() {
      final submitting = controller.isSubmitting.value;
      if (submitting) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
          ),
        );
      }
      return TextButton(
        onPressed: controller.submit,
        child: Text(
          controller.isEditMode ? '수정' : '등록',
          style: TextStyle(
            fontFamily: AppTypography.chivo,
            fontWeight: FontWeight.w800,
            fontSize: 15.sp,
            letterSpacing: 0.3,
            color: AppColors.accent,
          ),
        ),
      );
    });
  }

  // ── 본문 ──────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCategoryChips(),
                SizedBox(height: 16.h),
                _buildTitleField(),
                SizedBox(height: 4.h),
                _buildTitleCounter(),
                SizedBox(height: 12.h),
                _buildContentField(),
                SizedBox(height: 4.h),
                _buildContentCounter(),
              ],
            ),
          ),
        ),
        _buildImageBar(),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40.h,
      child: Obx(() {
        final selected = controller.selectedCategory.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _writableCategories.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (_, index) {
            final code = _writableCategories[index];
            final isSelected = code == selected;
            return GestureDetector(
              onTap: () => controller.selectCategory(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.chipBg,
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.cardBorder,
                  ),
                ),
                child: Text(
                  CommunityController.labelKoOf(code),
                  style: AppTypography.labelLg.copyWith(
                    fontSize: 12.sp,
                    letterSpacing: 0.2,
                    color: isSelected ? AppColors.accentDark : Colors.white,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: controller.titleController,
      onChanged: controller.onTitleChanged,
      maxLength: CommunityComposeController.maxTitleLength,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: Colors.white,
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
      ),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        counterText: '',
        hintText: '제목을 입력해주세요',
        hintStyle: TextStyle(
          color: AppColors.hint,
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.accent, width: 1.4),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
      ),
    );
  }

  Widget _buildTitleCounter() {
    return Obx(
      () => _counterText(
        controller.titleLength.value,
        CommunityComposeController.maxTitleLength,
      ),
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: controller.contentController,
      onChanged: controller.onContentChanged,
      maxLength: CommunityComposeController.maxContentLength,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      maxLines: null,
      minLines: 10,
      style: TextStyle(color: Colors.white, fontSize: 15.sp, height: 1.6),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        counterText: '',
        hintText: '어떤 이야기를 나누고 싶으신가요?',
        hintStyle: TextStyle(color: AppColors.hint, fontSize: 15.sp),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }

  Widget _buildContentCounter() {
    return Obx(
      () => _counterText(
        controller.contentLength.value,
        CommunityComposeController.maxContentLength,
      ),
    );
  }

  Widget _counterText(int current, int max) {
    final isOver = current > max;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '$current / $max',
        style: AppTypography.bodyMd.copyWith(
          fontSize: 11.sp,
          color: isOver ? AppColors.liveRed : AppColors.subtleText,
        ),
      ),
    );
  }

  // ── 이미지 첨부 바 ─────────────────────────────────────────────────────

  Widget _buildImageBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
      child: Obx(() {
        final existing = controller.existingImagePaths;
        final picked = controller.pickedImages;
        final total = existing.length + picked.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 15.sp,
                  color: AppColors.subtleText,
                ),
                SizedBox(width: 6.w),
                Text(
                  '사진 $total / ${CommunityComposeController.maxImages}',
                  style: AppTypography.bodyMd.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.subtleText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SizedBox(
              height: 72.w,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildAddButton(total),
                  for (var i = 0; i < existing.length; i++) ...[
                    SizedBox(width: 8.w),
                    _buildThumb(
                      child: CachedNetworkImage(
                        imageUrl: _publicUrl(existing[i]),
                        fit: BoxFit.cover,
                        width: 72.w,
                        height: 72.w,
                        errorWidget:
                            (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              size: 20.sp,
                              color: AppColors.muted,
                            ),
                      ),
                      onRemove: () => controller.removeExistingImage(i),
                    ),
                  ],
                  for (var i = 0; i < picked.length; i++) ...[
                    SizedBox(width: 8.w),
                    _buildThumb(
                      child: Image.file(
                        picked[i],
                        fit: BoxFit.cover,
                        width: 72.w,
                        height: 72.w,
                      ),
                      onRemove: () => controller.removeImage(i),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildAddButton(int total) {
    final isFull = total >= CommunityComposeController.maxImages;
    return GestureDetector(
      onTap: isFull ? null : controller.pickImages,
      child: Container(
        width: 72.w,
        height: 72.w,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isFull ? AppColors.inactive : AppColors.cardBorder,
          ),
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          size: 22.sp,
          color: isFull ? AppColors.muted : AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildThumb({required Widget child, required VoidCallback onRemove}) {
    return SizedBox(
      width: 72.w,
      height: 72.w,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10.r), child: child),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                margin: EdgeInsets.all(3.w),
                padding: EdgeInsets.all(2.w),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 13.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// DB 에는 상대 경로가 저장되므로 표시 직전에 공개 URL 로 바꾼다
  /// (`CommunityPostResponse.imageUrls` 와 같은 변환).
  String _publicUrl(String path) {
    return Supabase.instance.client.storage
        .from('community')
        .getPublicUrl(path);
  }

  // ── 이탈 확인 · 에러 ───────────────────────────────────────────────────

  /// 뒤로가기 / 닫기 — 작성 중인 내용이 있으면 확인을 받는다.
  Future<void> _handleBack() async {
    if (controller.isSubmitting.value) return;
    if (!controller.hasUnsavedInput) {
      Get.back<bool>();
      return;
    }

    final discard = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          controller.isEditMode ? '수정 취소' : '작성 취소',
          style: AppTypography.labelLg.copyWith(
            fontSize: 16.sp,
            color: Colors.white,
          ),
        ),
        content: Text(
          '지금 나가면 작성한 내용이 사라집니다.\n나가시겠습니까?',
          style: AppTypography.bodyMd.copyWith(
            fontSize: 14.sp,
            color: AppColors.subtleText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text(
              '계속 작성',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.subtleText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: Text(
              '나가기',
              style: AppTypography.labelLg.copyWith(
                fontSize: 14.sp,
                color: AppColors.liveRed,
              ),
            ),
          ),
        ],
      ),
    );

    if (discard == true) Get.back<bool>();
  }

  Widget _buildLoadError(String message) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 60.h),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48.sp,
            color: AppColors.subtleText,
          ),
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
              onPressed: controller.retryLoad,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentDark,
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
}
