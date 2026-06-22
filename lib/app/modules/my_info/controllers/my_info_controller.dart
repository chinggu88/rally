import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/profile_response.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../../services/notification_service.dart';
import '../../../../theme/app_colors.dart';

class MyInfoController extends GetxController {
  static MyInfoController get to => Get.find();

  final AuthRepository _authRepository = Get.find<AuthRepository>();
  final ProfileRepository _profileRepository = Get.find<ProfileRepository>();
  final AccountRepository _accountRepository = AccountRepository();
  StreamSubscription<AuthState>? _authSub;

  final _isLoggedIn = false.obs;
  bool get isLoggedIn => _isLoggedIn.value;

  String? get email => _authRepository.currentUser?.email;

  // 프로필 상태
  final _nickname = RxnString();
  String? get nickname => _nickname.value;

  final _avatarUrl = RxnString();
  String? get avatarUrl => _avatarUrl.value;

  final _notificationsEnabled = true.obs;
  bool get notificationsEnabled => _notificationsEnabled.value;

  final _isDeleting = false.obs;
  bool get isDeleting => _isDeleting.value;

  @override
  void onInit() {
    super.onInit();
    _isLoggedIn.value = _authRepository.currentSession != null;
    if (_isLoggedIn.value) loadProfile();
    _authSub = _authRepository.authStateChanges.listen((state) {
      final loggedIn = state.session != null;
      _isLoggedIn.value = loggedIn;
      if (loggedIn) {
        loadProfile();
      } else {
        _nickname.value = null;
        _avatarUrl.value = null;
        _notificationsEnabled.value = true;
      }
    });
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  /// 프로필(닉네임/아바타/알림설정)을 다시 불러온다.
  /// 프로필 편집 후에도 호출해 화면을 갱신한다.
  Future<void> loadProfile() async {
    try {
      final ProfileResponse? profile = await _profileRepository.fetchMyProfile();
      if (profile != null) {
        _nickname.value = profile.nickname;
        _avatarUrl.value = profile.avatarUrl;
        _notificationsEnabled.value = profile.notificationsEnabled;
      }
    } catch (e) {
      log('MyInfoController.loadProfile error: $e');
    }
  }

  /// 비로그인 안내 화면 → 로그인 화면으로 이동
  void goToLogin() {
    if (Get.currentRoute == Routes.LOGIN) return; // 중복 push 방지
    Get.toNamed(Routes.LOGIN);
  }

  /// 비로그인 안내 화면 → 회원가입(이메일 인증) 화면으로 이동
  void goToSignUp() {
    if (Get.currentRoute == Routes.SIGN_UP) return;
    Get.toNamed(Routes.SIGN_UP);
  }

  void goToProfileEdit() {
    Get.toNamed(Routes.PROFILE_EDIT);
  }

  void goToFavoritePlayers() {
    Get.toNamed(Routes.FAVORITE_PLAYERS);
  }

  /// 아직 구현되지 않은 메뉴 항목에 대한 안내.
  void _showComingSoon(String label) {
    Get.snackbar(
      label,
      '곧 제공될 예정입니다.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void goToInviteFriends() => _showComingSoon('친구 초대');
  void goToBecomeSpecialist() => _showComingSoon('전문가 되기');
  void goToHelp() => _showComingSoon('도움말');
  void goToFeedback() => _showComingSoon('피드백 보내기');

  /// 알림 on/off 토글 — profiles 플래그 + 디바이스 토큰 등록/삭제.
  Future<void> toggleNotifications(bool enabled) async {
    final previous = _notificationsEnabled.value;
    _notificationsEnabled.value = enabled; // 낙관적 반영
    try {
      await _profileRepository.updateNotificationsEnabled(enabled);
      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.setPushEnabled(enabled);
      }
    } catch (e) {
      _notificationsEnabled.value = previous; // 롤백
      log('MyInfoController.toggleNotifications error: $e');
      Get.snackbar(
        '알림 설정 실패',
        '잠시 후 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
      Get.snackbar(
        '로그아웃',
        '안녕히 가세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on AuthException catch (e) {
      Get.snackbar(
        '로그아웃 실패',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 회원탈퇴 — 확인 다이얼로그 후 계정 영구 삭제.
  Future<void> confirmDeleteAccount() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('회원탈퇴', style: TextStyle(color: Colors.white)),
        content: const Text(
          '계정과 모든 데이터(좋아하는 선수, 알림 설정 등)가 영구 삭제됩니다.\n정말 탈퇴하시겠어요?',
          style: TextStyle(color: AppColors.subtleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('취소', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('탈퇴', style: TextStyle(color: AppColors.liveRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      _isDeleting.value = true;
      await _accountRepository.deleteAccount();
      Get.offAllNamed(Routes.APP);
      Get.snackbar(
        '회원탈퇴 완료',
        '이용해주셔서 감사합니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '회원탈퇴 실패',
        '잠시 후 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isDeleting.value = false;
    }
  }
}
