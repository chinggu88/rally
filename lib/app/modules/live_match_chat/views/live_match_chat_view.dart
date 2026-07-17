import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../data/models/chat_message_response.dart';
import '../controllers/live_match_chat_controller.dart';
import 'widgets/chat_day_divider.dart';
import 'widgets/chat_live_status_pill.dart';
import 'widgets/chat_message_bubble.dart';

/// 라이브 매치 채팅방 화면.
///
/// Stitch "커뮤니티 대화방 (매거진)" 디자인 적용.
///   - AppBar: 큰 타이틀 + "n ONLINE • LIVE MATCH" 서브라인
///   - 메시지 리스트 (reverse 스크롤): 데이 디바이더, 메시지 버블, 라이브 상태 pill
///   - 입력바: pill 입력창 + 라임 send 버튼
class LiveMatchChatView extends GetView<LiveMatchChatController> {
  const LiveMatchChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [Expanded(child: _buildMessageList()), _buildComposer()],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final title = _resolveTitle();
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18.sp,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 2.h),
          Obx(() {
            final count = controller.onlineCount;
            return Text(
              '${_formatCount(count)}명 접속중',
              style: TextStyle(
                color: AppColors.subtleText,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            );
          }),
        ],
      ),
    );
  }

  String _resolveTitle() {
    final tournament = controller.tournamentName;
    if (tournament != null && tournament.trim().isNotEmpty) {
      return tournament.trim().toUpperCase();
    }
    final p1 =
        controller.team1Names.isNotEmpty ? controller.team1Names.first : null;
    final p2 =
        controller.team2Names.isNotEmpty ? controller.team2Names.first : null;
    if (p1 != null && p2 != null) {
      return '$p1 VS $p2'.toUpperCase();
    }
    return 'LIVE CHAT';
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
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
      final items = _buildListItems(myId);
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200.h) {
            controller.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          reverse: true,
          padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
          itemCount: items.length + (controller.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (controller.isLoadingMore && index == items.length) {
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
            return items[index];
          },
        ),
      );
    });
  }

  /// reverse=true 기준으로 그릴 위젯 리스트.
  /// index 0이 가장 최신(아래)이 되도록 시간순 정렬된 메시지를 뒤집어 만든다.
  /// 날짜가 바뀌는 지점마다 데이 디바이더를 삽입하고, 최신 메시지 위에 라이브 상태 pill을 노출한다.
  List<Widget> _buildListItems(String? myId) {
    final asc = controller.messages; // 오래된 → 최신
    final widgets = <Widget>[];

    // 시간 오름차순으로 한 번 훑으며 디바이더와 버블을 만든다.
    DateTime? prevDay;
    for (var i = 0; i < asc.length; i++) {
      final m = asc[i];
      final day = DateTime(
        m.createdAt.year,
        m.createdAt.month,
        m.createdAt.day,
      );
      final dayChanged = prevDay == null || prevDay != day;
      if (dayChanged) {
        widgets.add(ChatDayDivider(label: _dayLabel(day)));
        prevDay = day;
      }

      final prev = i > 0 ? asc[i - 1] : null;
      final next = i + 1 < asc.length ? asc[i + 1] : null;

      // 그룹 첫 메시지: 날짜가 바뀌었거나 이전 메시지의 보낸 사람이 다름
      final isFirstInGroup =
          dayChanged || prev == null || prev.userId != m.userId;

      // 다음 메시지가 같은 사람 + 같은 분이면 시간은 마지막 메시지에서만 표시
      final showTime =
          next == null ||
          next.userId != m.userId ||
          !_sameMinute(next.createdAt, m.createdAt);

      widgets.add(
        ChatMessageBubble(
          key: ValueKey(m.id),
          message: m,
          isMine: m.userId == myId,
          isFirstInGroup: isFirstInGroup,
          showTime: showTime,
          onLongPress: () => _confirmDelete(m),
        ),
      );
    }

    // 라이브 상태 pill: 가장 최신 메시지 바로 위에 1회 노출. 실시간 스코어 표시.
    if (widgets.isNotEmpty) {
      widgets.add(_buildLivePill());
    }

    // reverse=true이므로 마지막 항목이 화면 최상단. index 0이 최신이 되도록 뒤집는다.
    return widgets.reversed.toList();
  }

  /// 라이브 스코어보드 pill. controller.liveScore(Realtime 갱신)에서
  /// 진행 중인 게임 점수와 세트 번호를 파싱해 전달한다.
  Widget _buildLivePill() {
    final pairs = _scorePairs(controller.liveScore);
    List<int>? current;
    int? setNumber;
    for (var i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      // 완료 게임 판정(21점 이상 + 2점차)은 LiveMatchResponse.currentGameIndex와 동일.
      final done = (p[0] >= 21 || p[1] >= 21) && (p[0] - p[1]).abs() >= 2;
      if (!done) {
        current = p;
        setNumber = i + 1;
        break;
      }
    }
    if (current == null && pairs.isNotEmpty) {
      current = pairs.last;
      setNumber = pairs.length;
    }
    return ChatLiveStatusPill(
      team1Name: _teamLabel(controller.team1Names),
      team2Name: _teamLabel(controller.team2Names),
      team1Score: current?[0],
      team2Score: current?[1],
      setNumber: setNumber,
    );
  }

  /// 스코어 문자열(예: "21-18, 15-12")을 게임별 점수쌍 리스트로 파싱.
  static List<List<int>> _scorePairs(String? score) {
    if (score == null || score.trim().isEmpty) return const [];
    final pairs = <List<int>>[];
    for (final m in RegExp(r'(\d+)\s*[-:/]\s*(\d+)').allMatches(score)) {
      pairs.add(<int>[int.parse(m.group(1)!), int.parse(m.group(2)!)]);
    }
    return pairs;
  }

  /// 팀 표시 이름. 복식은 두 선수를 ' / '로 연결.
  static String _teamLabel(List<String> names) {
    if (names.isEmpty) return 'TBD';
    return names.take(2).map((n) => n.trim()).join(' / ');
  }

  static bool _sameMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final base =
        diff == 0
            ? 'TODAY'
            : diff == 1
            ? 'YESTERDAY'
            : '${day.year}.${day.month.toString().padLeft(2, '0')}.${day.day.toString().padLeft(2, '0')}';
    final suffix = controller.tournamentName;
    if (suffix != null && suffix.trim().isNotEmpty) {
      return '$base — ${suffix.trim().toUpperCase()}';
    }
    return base;
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
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1F1D),
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // _circleIconButton(icon: Icons.add_rounded, onTap: () {}),
              SizedBox(width: 10.w),
              Expanded(
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
                    hintText: 'Join the discussion...',
                    hintStyle: TextStyle(
                      color: AppColors.hint,
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                ),
              ),
              // SizedBox(width: 6.w),
              // IconButton(
              //   onPressed: () {},
              //   icon: Icon(
              //     Icons.image_outlined,
              //     color: AppColors.subtleText,
              //     size: 22.sp,
              //   ),
              // ),
              SizedBox(width: 10.w),
              Obx(
                () => GestureDetector(
                  onTap:
                      controller.isSending
                          ? null
                          : controller.sendComposerMessage,
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.accentLime,
                      borderRadius: BorderRadius.circular(22.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentLime.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child:
                        controller.isSending
                            ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A1F00),
                              ),
                            )
                            : Icon(
                              Icons.send_rounded,
                              color: const Color(0xFF1A1F00),
                              size: 20.sp,
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFF3A3F3C), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.subtleText, size: 20.sp),
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
