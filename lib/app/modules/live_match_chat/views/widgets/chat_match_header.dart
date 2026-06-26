import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';

/// 채팅방 상단 매치 정보 카드 (고정).
///
/// 진입 시점 스냅샷 데이터를 표시한다. 라이브 스코어 갱신은 v2.
class ChatMatchHeader extends StatelessWidget {
  const ChatMatchHeader({
    super.key,
    required this.team1Names,
    required this.team2Names,
    this.team1Country,
    this.team2Country,
    this.eventName,
    this.roundName,
    this.tournamentName,
    this.courtName,
    this.score,
  });

  final List<String> team1Names;
  final List<String> team2Names;
  final String? team1Country;
  final String? team2Country;
  final String? eventName;
  final String? roundName;
  final String? tournamentName;
  final String? courtName;
  final String? score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1.h),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMeta(),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(child: _buildTeam(team1Names, team1Country, true)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  score ?? 'VS',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontFamily: AppTypography.chivo,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.sp,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Expanded(child: _buildTeam(team2Names, team2Country, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeta() {
    final parts = <String>[
      if (tournamentName != null && tournamentName!.isNotEmpty) tournamentName!,
      if (eventName != null && eventName!.isNotEmpty) eventName!,
      if (roundName != null && roundName!.isNotEmpty) roundName!,
      if (courtName != null && courtName!.isNotEmpty) courtName!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.subtleText,
        fontSize: 11.sp,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTeam(List<String> names, String? country, bool leading) {
    final display = names.isEmpty ? 'TBD' : names.join(' / ');
    return Column(
      crossAxisAlignment:
          leading ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          display,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: leading ? TextAlign.start : TextAlign.end,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13.sp,
            height: 1.25,
          ),
        ),
        if (country != null && country.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            country,
            style: TextStyle(
              color: AppColors.subtleText,
              fontSize: 11.sp,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}
