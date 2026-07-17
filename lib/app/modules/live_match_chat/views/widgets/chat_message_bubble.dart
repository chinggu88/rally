import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../data/models/chat_message_response.dart';

/// 채팅 메시지 1개 버블.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isFirstInGroup = true,
    this.showTime = true,
    this.onLongPress,
  });

  final ChatMessageResponse message;
  final bool isMine;

  /// 같은 사람 연속 메시지 그룹의 첫 메시지 여부. 아바타/닉네임 표시에 사용.
  final bool isFirstInGroup;

  /// 시간(HH:MM) 표시 여부. 같은 사람 + 같은 분 그룹의 마지막 메시지에만 true.
  final bool showTime;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isMine ? onLongPress : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, isFirstInGroup ? 10.h : 2.h, 16.w, 10.h),
        child: isMine ? _buildMine() : _buildOther(),
      ),
    );
  }

  Widget _buildOther() {
    final displayName = _displayName();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFirstInGroup)
          _buildAvatar(displayName)
        else
          SizedBox(width: 36.w),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFirstInGroup) ...[
                Text(
                  displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
              ],
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2220),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
              ),
              if (showTime) ...[
                SizedBox(height: 6.h),
                Text(
                  _formatHm(message.createdAt),
                  style: TextStyle(
                    color: AppColors.hint,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMine() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 0.78.sw),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.accentLime,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: const Color(0xFF1A1F00),
              fontSize: 14.sp,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (showTime) ...[
          SizedBox(height: 6.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatHm(message.createdAt),
                style: TextStyle(
                  color: AppColors.hint,
                  fontSize: 11.sp,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.done_all_rounded,
                size: 12.sp,
                color: AppColors.accentLime,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(String displayName) {
    final url = message.authorAvatarUrl;
    final hasUrl = url != null && url.isNotEmpty;
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        color: hasUrl ? AppColors.cardBg : _colorFor(message.userId),
        borderRadius: BorderRadius.circular(8.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _buildInitial(displayName),
            )
          : _buildInitial(displayName),
    );
  }

  Widget _buildInitial(String name) {
    final initial = _initialOf(name);
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _displayName() {
    final nick = message.authorNickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    // user_id 앞 4자리로 일관된 fallback ID 생성 (UUID에서 하이픈 제외 후 앞 4자리)
    final id = message.userId.replaceAll('-', '');
    final suffix = id.length >= 4 ? id.substring(0, 4) : id;
    return 'User_$suffix';
  }

  static String _initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final ch = trimmed.characters.first;
    return ch.toUpperCase();
  }

  /// user_id 해시 기반 일관 컬러. 같은 유저는 항상 같은 색.
  static Color _colorFor(String userId) {
    const palette = <Color>[
      Color(0xFF7C5CFF),
      Color(0xFF35B36E),
      Color(0xFFFF6B6B),
      Color(0xFFFFA94D),
      Color(0xFF22B8CF),
      Color(0xFFE64980),
      Color(0xFF5C7CFA),
      Color(0xFFFFD43B),
    ];
    var hash = 0;
    for (final code in userId.codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }

  static String _formatHm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
