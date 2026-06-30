import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';

/// 채팅 리스트 안의 날짜/카테고리 디바이더 pill.
class ChatDayDivider extends StatelessWidget {
  const ChatDayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1F1D),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.subtleText,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
