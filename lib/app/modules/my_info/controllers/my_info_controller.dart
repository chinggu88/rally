import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final ProfileResponse? profile =
          await _profileRepository.fetchMyProfile();
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

  /// 차단한 사용자 목록. 차단을 걸 수 있는 것만으로는 부족하고 되돌릴 수도
  /// 있어야 한다는 것이 Apple App Review Guideline 1.2 의 요구다.
  void goToBlockedUsers() {
    Get.toNamed(Routes.COMMUNITY_BLOCKED_USERS);
  }

  /// 커뮤니티 이용규칙 상시 열람. 동의 시점 외에도 언제든 볼 수 있어야 한다
  /// (Guideline 1.2 / 기획서 S-6). 로그인 없이도 열린다.
  void goToCommunityTerms() {
    Get.toNamed(Routes.COMMUNITY_TERMS);
  }

  /// 아직 구현되지 않은 메뉴 항목에 대한 안내.
  void _showComingSoon(String label) {
    Get.snackbar(label, '곧 제공될 예정입니다.', snackPosition: SnackPosition.BOTTOM);
  }

  void goToInviteFriends() => _showComingSoon('친구 초대');
  void goToBecomeSpecialist() => _showComingSoon('전문가 되기');

  /// 앱 내 개발자 연락 경로 (Apple App Review Guideline 1.2).
  ///
  /// UGC(커뮤니티·라이브 채팅)를 제공하는 앱은 신고·차단과 함께 **개발자에게
  /// 직접 연락할 수단**을 앱 안에 두어야 한다. 별도 문의 화면 대신 기본 메일
  /// 앱을 여는 것으로 충족한다.
  Future<void> goToHelp() => _composeSupportMail('도움말 문의');
  Future<void> goToFeedback() => _composeSupportMail('피드백');

  /// 문의 메일 수신 주소.
  static const String supportEmail = 'cuunit.store@gmail.com';

  /// `mailto:` 를 연다.
  ///
  /// 제목에 앱 버전(빌드 번호 포함)을 넣어 두면 사용자가 따로 적지 않아도
  /// 어느 빌드에서 온 문의인지 알 수 있다. 버전 조회에 실패해도 메일 자체는
  /// 열려야 하므로 조회 실패는 삼키고 제목만 짧아진다.
  ///
  /// 메일 앱이 없는 기기에서는 `launchUrl` 이 false 를 돌려주거나 예외를
  /// 던진다. 둘 다 조용히 넘기지 않고 주소를 안내한다 — 아무 반응도 없으면
  /// 사용자는 연락 수단이 없다고 판단한다.
  Future<void> _composeSupportMail(String label) async {
    final subject = '[Rally] $label${await _versionSuffix()}';
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _showMailFallback();
    } catch (e) {
      log('MyInfoController._composeSupportMail error: $e');
      _showMailFallback();
    }
  }

  Future<String> _versionSuffix() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return ' (v${info.version}+${info.buildNumber})';
    } catch (e) {
      log('MyInfoController._versionSuffix error: $e');
      return '';
    }
  }

  void _showMailFallback() {
    Get.snackbar(
      '메일 앱을 열 수 없습니다',
      '$supportEmail 으로 보내주세요.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

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
      Get.snackbar('로그아웃', '안녕히 가세요.', snackPosition: SnackPosition.BOTTOM);
      _isLoggedIn.value = false;
    } on AuthException catch (e) {
      Get.snackbar('로그아웃 실패', e.message, snackPosition: SnackPosition.BOTTOM);
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
