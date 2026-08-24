import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/blocked_user_response.dart';
import '../../../data/repositories/community_moderation_repository.dart';
import '../../../utils/community_error.dart';
import 'community_controller.dart';

/// 차단한 사용자 목록 화면 컨트롤러 (내정보 → 차단한 사용자).
///
/// 목록에는 **내가 건 차단만** 담긴다 — `ub_select_own` 정책이 그렇게 막고,
/// 나를 차단한 사람을 보여주지 않는 것이 의도된 설계다.
class BlockedUsersController extends GetxController {
  final CommunityModerationRepository _repository =
      Get.find<CommunityModerationRepository>();

  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final _blockedUsers = <BlockedUserResponse>[].obs;
  List<BlockedUserResponse> get blockedUsers => _blockedUsers;

  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  /// 해제 요청 진행 중인 사용자 id. 같은 항목의 중복 요청을 막는다.
  final _unblockingId = RxnString();
  String? get unblockingId => _unblockingId.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      _isLoading.value = true;
      _errorMessage.value = null;
      final list = await _repository.listBlockedUsers();
      _blockedUsers.assignAll(list);
    } catch (e) {
      log('BlockedUsersController.load error: $e');
      _errorMessage.value = communityErrorMessage(e);
    } finally {
      _isLoading.value = false;
    }
  }

  /// 차단 해제 — 확인 다이얼로그 → 해제 → 목록에서 제거.
  ///
  /// 해제하면 상대의 글·댓글이 다시 보이므로, 커뮤니티 목록이 살아 있으면
  /// 함께 새로고침한다. 필터링 자체는 서버 RLS 가 하기 때문에 목록을 다시
  /// 부르는 것 말고 클라이언트가 할 일은 없다.
  Future<void> unblock(BlockedUserResponse user) async {
    final id = user.blockedId;
    if (id == null || id.isEmpty) return;
    if (_unblockingId.value != null) return;

    final confirmed = await _confirmUnblock(user.displayName);
    if (confirmed != true) return;

    _unblockingId.value = id;
    try {
      await _repository.unblockUser(id);
      _blockedUsers.removeWhere((u) => u.blockedId == id);
      if (Get.isRegistered<CommunityController>()) {
        await CommunityController.to.refreshPosts();
      }
      Get.snackbar(
        '차단 해제',
        '${user.displayName}님의 차단을 해제했습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('BlockedUsersController.unblock error: $e');
      Get.snackbar(
        '차단 해제 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _unblockingId.value = null;
    }
  }

  Future<bool?> _confirmUnblock(String displayName) {
    return Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          '차단 해제',
          style: AppTypography.labelLg.copyWith(
            fontSize: 16.sp,
            color: Colors.white,
          ),
        ),
        content: Text(
          '$displayName님의 차단을 해제할까요?\n해제하면 이 사용자의 글과 댓글이 다시 보입니다.',
          style: AppTypography.bodyMd.copyWith(
            fontSize: 14.sp,
            color: AppColors.subtleText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text(
              '취소',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.subtleText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: Text(
              '해제',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
