import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';

/// 라이브 스코어보드 배너.
///
/// "이름 점수 VS 점수 이름 SET n"을 한 줄로 표시한다.
/// 이름이 길면 말줄임(...) 처리.
class ChatLiveStatusPill extends StatelessWidget {
  const ChatLiveStatusPill({
    super.key,
    required this.team1Name,
    required this.team2Name,
    this.team1Score,
    this.team2Score,
    this.setNumber,
  });

  final String team1Name;
  final String team2Name;
  final int? team1Score;
  final int? team2Score;
  final int? setNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF161A16),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF2A2F2A), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _buildName(team1Name, TextAlign.right)),
          SizedBox(width: 8.w),
          _buildScore(team1Score),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Text(
              'VS',
              style: TextStyle(
                color: AppColors.hint,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: 1.0,
              ),
            ),
          ),
          _buildScore(team2Score),
          SizedBox(width: 8.w),
          Expanded(child: _buildName(team2Name, TextAlign.left)),
          if (setNumber != null) ...[
            SizedBox(width: 10.w),
            Text(
              'SET $setNumber',
              style: TextStyle(
                color: AppColors.subtleText,
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildName(String name, TextAlign align) {
    return Text(
      name.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildScore(int? score) {
    return Text(
      score?.toString() ?? '-',
      style: TextStyle(
        color: AppColors.accentLime,
        fontSize: 18.sp,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
    );
  }
}
