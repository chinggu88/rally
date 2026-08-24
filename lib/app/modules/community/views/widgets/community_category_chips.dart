import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../controllers/community_controller.dart';

/// 커뮤니티 카테고리 칩 그룹 (전체 / 자유 / 경기토론 / 장비 / 파트너찾기).
///
/// 가로 스크롤 `ListView.separated` — `PlayerView` 의 칩 패턴을 따른다.
/// 상태를 직접 읽지 않고 [selected] / [onSelected] 로만 통신해, 리빌드 범위를
/// 호출부의 `Obx` 안으로 가둔다.
class CommunityCategoryChips extends StatelessWidget {
  const CommunityCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// 현재 선택된 카테고리 코드. null이면 "전체".
  final String? selected;

  /// 칩 탭 콜백. "전체"는 null을 전달한다.
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        itemCount: CommunityController.categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final code = CommunityController.categories[index];
          return _CategoryChip(
            label: CommunityController.labelKoOf(code),
            selected: code == selected,
            onTap: () => onSelected(code),
          );
        },
      ),
    );
  }
}

/// 단일 카테고리 칩 (선택 시 라임 옐로우 fill)
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
            color: selected ? AppColors.accent : AppColors.chipBg,
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.cardBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.labelLg.copyWith(
              fontSize: 12.sp,
              letterSpacing: 0.2,
              color: selected ? AppColors.accentDark : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
