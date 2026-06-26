import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../data/models/chat_message_response.dart';
import '../controllers/live_match_chat_controller.dart';
import 'widgets/chat_match_header.dart';
import 'widgets/chat_message_bubble.dart';

/// 라이브 매치 채팅방 화면.
///
/// 구조:
///   - AppBar
///   - 상단 고정 매치 정보 (ChatMatchHeader)
///   - 메시지 리스트 (reverse 스크롤, 위로 당기면 이전 페이지)
///   - 하단 입력바
class LiveMatchChatView extends GetView<LiveMatchChatController> {
  const LiveMatchChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '라이브 채팅',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ChatMatchHeader(
              team1Names: controller.team1Names,
              team2Names: controller.team2Names,
              team1Country: controller.team1Country,
              team2Country: controller.team2Country,
              eventName: controller.eventName,
              roundName: controller.roundName,
              tournamentName: controller.tournamentName,
              courtName: controller.courtName,
              score: controller.scoreSnapshot,
            ),
            Expanded(child: _buildMessageList()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Obx(() {
      if (controller.isLoading && controller.messages.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.accentLime),
        );
      }
      if (controller.errorMessage != null && controller.messages.isEmpty) {
        return _buildCenter(controller.errorMessage!, retry: true);
      }
      if (controller.messages.isEmpty) {
        return _buildCenter('첫 번째 응원 메시지를 남겨보세요!');
      }
      final myId = controller.currentUserId;
      // reverse=true이므로 ASC 리스트를 그대로 사용하되 builder가 뒤에서부터 그린다.
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // reverse=true에서 위로 스크롤 시 maxScrollExtent에 근접
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200.h) {
            controller.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          reverse: true,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          itemCount: controller.messages.length +
              (controller.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // reverse=true이므로 index 0이 가장 최신.
            // 가장 위쪽(=index가 가장 큰 항목 다음)에 로딩 인디케이터.
            if (controller.isLoadingMore &&
                index == controller.messages.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentLime,
                    ),
                  ),
                ),
              );
            }
            final reverseIndex = controller.messages.length - 1 - index;
            final m = controller.messages[reverseIndex];
            return ChatMessageBubble(
              key: ValueKey(m.id),
              message: m,
              isMine: m.userId == myId,
              onLongPress: () => _confirmDelete(m),
            );
          },
        ),
      );
    });
  }

  Future<void> _confirmDelete(ChatMessageResponse message) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('메시지 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '이 메시지를 삭제할까요?',
          style: TextStyle(color: AppColors.subtleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('삭제', style: TextStyle(color: AppColors.downRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deleteMessage(message);
    }
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 8.h),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1.h)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: TextField(
                  controller: controller.composer,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: LiveMatchChatController.maxContentLen,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => controller.sendComposerMessage(),
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  cursorColor: AppColors.accentLime,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '메시지 보내기',
                    hintStyle: TextStyle(
                      color: AppColors.hint,
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            SizedBox(width: 6.w),
            Obx(
              () => IconButton(
                onPressed: controller.isSending
                    ? null
                    : controller.sendComposerMessage,
                icon: controller.isSending
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentLime,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: AppColors.accentLime,
                        size: 24.sp,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter(String text, {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.subtleText,
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
          if (retry) ...[
            SizedBox(height: 14.h),
            OutlinedButton(
              onPressed: controller.loadInitial,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentLime,
                side: const BorderSide(color: AppColors.accentLime),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }
}
