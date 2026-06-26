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
    this.onLongPress,
  });

  final ChatMessageResponse message;
  final bool isMine;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.accent : AppColors.cardBg;
    final textColor = isMine ? AppColors.accentDark : Colors.white;
    final radius = Radius.circular(14.r);

    return GestureDetector(
      onLongPress: isMine ? onLongPress : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMine) ...[
              _buildAvatar(),
              SizedBox(width: 8.w),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine) ...[
                    Text(
                      message.authorNickname ?? '익명',
                      style: TextStyle(
                        color: AppColors.subtleText,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                  ],
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: radius,
                        topRight: radius,
                        bottomLeft: isMine ? radius : Radius.zero,
                        bottomRight: isMine ? Radius.zero : radius,
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.sp,
                        height: 1.35,
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    _formatHm(message.createdAt),
                    style: TextStyle(
                      color: AppColors.hint,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = message.authorAvatarUrl;
    return CircleAvatar(
      radius: 14.r,
      backgroundColor: AppColors.cardBg,
      backgroundImage:
          (url != null && url.isNotEmpty) ? CachedNetworkImageProvider(url) : null,
      child: (url == null || url.isEmpty)
          ? Icon(Icons.person, color: AppColors.subtleText, size: 14.sp)
          : null,
    );
  }

  static String _formatHm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
