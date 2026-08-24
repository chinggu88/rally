import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/community_moderation_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/community_error.dart';
import '../../../utils/community_text_filter.dart';
import '../../my_info/controllers/my_info_controller.dart';
import '../views/widgets/community_eula_sheet.dart';

/// 커뮤니티 온보딩 시트(S-6) 컨트롤러 — 닉네임 설정 + 이용규칙 동의.
///
/// 시트가 열려 있는 동안만 살아 있는 단명 컨트롤러라 바인딩이 아니라
/// [ensureCanWrite] 가 `Get.put` / `Get.delete` 로 직접 수명을 관리한다.
///
/// **작성 게이트([ensureCanWrite])가 이 클래스에 있는 이유**: 게이트는 작성
/// 화면에 *들어가기 전에* 통과해야 하므로 `CommunityComposeController` 에 둘 수
/// 없다(그 컨트롤러는 화면 진입 후에야 생성된다). 목록 FAB · 상세 수정 메뉴 ·
/// 댓글 입력(TASK-012)이 모두 같은 진입점을 쓴다.
class CommunityOnboardingController extends GetxController {
  CommunityOnboardingController({
    required this.needsNickname,
    required this.needsAgreement,
    String? initialNickname,
  }) : _initialNickname = initialNickname;

  /// 닉네임 입력란을 보여줄지. 이미 닉네임이 있으면 false — 약관만 받는다.
  final bool needsNickname;

  /// 이용규칙 동의를 받아야 하는지. 버전이 올라 재동의가 필요할 때도 true.
  final bool needsAgreement;

  final String? _initialNickname;

  /// 닉네임 길이 규격 (기획서 §5-5). 서버는 `char_length` 제약이 아니라
  /// 유니크 인덱스·금칙어 트리거만 걸려 있으므로 길이는 클라이언트 책임이다.
  static const int minNicknameLength = 2;
  static const int maxNicknameLength = 12;

  /// 입력이 멈춘 뒤 중복 검사를 보내기까지의 대기 시간.
  static const Duration _debounce = Duration(milliseconds: 400);

  final CommunityModerationRepository _moderationRepository =
      Get.find<CommunityModerationRepository>();
  final ProfileRepository _profileRepository = Get.find<ProfileRepository>();

  late final TextEditingController nicknameController;

  /// 닉네임 검증 실패 문구 (null이면 오류 없음)
  final nicknameError = RxnString();

  /// 사용 가능 판정 — 검증을 모두 통과했을 때만 true
  final isNicknameAvailable = false.obs;

  /// 중복 검사 요청 진행 중
  final isCheckingNickname = false.obs;

  /// 이용규칙 동의 체크박스
  final isAgreed = false.obs;

  /// 제출 진행 중 (버튼 비활성 + 인디케이터)
  final isSubmitting = false.obs;

  /// 이용규칙 원문. 로딩 실패해도 시트는 열린다(빈 문자열).
  final eulaText = ''.obs;
  final isEulaLoading = true.obs;

  Timer? _debounceTimer;

  /// 중복 검사 결과가 늦게 도착해 최신 입력을 덮어쓰지 않도록 하는 토큰.
  int _checkToken = 0;

  @override
  void onInit() {
    super.onInit();
    nicknameController = TextEditingController(text: _initialNickname ?? '');
    // 약관만 받는 경우 닉네임은 이미 유효하므로 검증을 건너뛴다.
    if (!needsNickname) {
      isNicknameAvailable.value = true;
    }
    _loadEula();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    nicknameController.dispose();
    super.onClose();
  }

  /// 제출 버튼 활성 조건.
  bool get canSubmit {
    if (isSubmitting.value) return false;
    if (needsAgreement && !isAgreed.value) return false;
    if (needsNickname && !isNicknameAvailable.value) return false;
    return true;
  }

  Future<void> _loadEula() async {
    try {
      eulaText.value = await rootBundle.loadString(
        CommunityModerationRepository.eulaAssetPath,
      );
    } catch (e) {
      // 애셋 누락은 배포 실수지 사용자 잘못이 아니다. 시트를 막지 않고
      // 안내 문구로 대체한다 — 동의 자체는 서버 기록이 본질이다.
      log('CommunityOnboardingController._loadEula error: $e');
      eulaText.value = '이용규칙을 불러오지 못했습니다.\n네트워크 상태를 확인한 뒤 다시 시도해주세요.';
    } finally {
      isEulaLoading.value = false;
    }
  }

  /// 닉네임 입력 변화 — 형식은 즉시, 중복은 디바운스 후 검사한다.
  void onNicknameChanged(String value) {
    _debounceTimer?.cancel();
    // 입력을 고치는 순간 이전 판정은 무효다. 사용자가 "사용 가능"을 보고
    // 글자를 더 친 뒤 그 표시를 믿고 제출하는 상황을 막는다.
    isNicknameAvailable.value = false;

    final formatError = _validateFormat(value);
    if (formatError != null) {
      isCheckingNickname.value = false;
      nicknameError.value = value.trim().isEmpty ? null : formatError;
      return;
    }

    nicknameError.value = null;
    isCheckingNickname.value = true;
    _debounceTimer = Timer(_debounce, () => _checkDuplicate(value));
  }

  /// 길이 · 금칙어 형식 검증. 통과하면 null.
  String? _validateFormat(String value) {
    final trimmed = value.trim();
    if (trimmed.length < minNicknameLength) {
      return '닉네임은 $minNicknameLength자 이상이어야 합니다.';
    }
    if (trimmed.length > maxNicknameLength) {
      return '닉네임은 $maxNicknameLength자를 넘을 수 없습니다.';
    }
    // 서버 `profiles_banned_nickname` 트리거와 같은 사전으로 미리 걸러낸다.
    final banned = CommunityTextFilter.findBannedWord(trimmed, _bannedWords);
    if (banned != null) {
      return '사용할 수 없는 닉네임입니다.';
    }
    return null;
  }

  List<String> _bannedWords = const <String>[];

  /// 금칙어 사전을 미리 받아 둔다. 실패해도 조용히 넘긴다 — 서버 트리거가
  /// 최종 권위라 사전 검증이 없어도 잘못된 닉네임이 저장되지는 않는다.
  Future<void> preloadBannedWords() async {
    try {
      _bannedWords = await _moderationRepository.fetchBannedWords();
    } catch (e) {
      log('CommunityOnboardingController.preloadBannedWords error: $e');
    }
  }

  Future<void> _checkDuplicate(String value) async {
    final token = ++_checkToken;
    final trimmed = value.trim();
    try {
      final taken = await _moderationRepository.isNicknameTaken(trimmed);
      if (token != _checkToken) return;
      if (taken) {
        nicknameError.value = '이미 사용 중인 닉네임입니다.';
        isNicknameAvailable.value = false;
      } else {
        nicknameError.value = null;
        isNicknameAvailable.value = true;
      }
    } catch (e) {
      if (token != _checkToken) return;
      // 확인에 실패했다고 입력을 막지는 않는다. 최종 판정은 저장 시점의
      // 23505 이므로, 여기서는 "확인 못 함" 상태로 두고 제출을 허용한다.
      log('CommunityOnboardingController._checkDuplicate error: $e');
      nicknameError.value = null;
      isNicknameAvailable.value = true;
    } finally {
      if (token == _checkToken) {
        isCheckingNickname.value = false;
      }
    }
  }

  /// "동의하고 계속" — 닉네임 저장 → 약관 동의 기록 → 시트를 true 로 닫는다.
  ///
  /// 순서가 중요하다. 닉네임 저장이 23505 로 실패했는데 동의만 먼저 기록되면
  /// `community_can_write()` 는 통과하지만 닉네임 없는 사용자가 글을 쓰게 된다.
  Future<void> submit() async {
    if (!canSubmit) return;

    final nickname = nicknameController.text.trim();
    if (needsNickname) {
      final formatError = _validateFormat(nickname);
      if (formatError != null) {
        nicknameError.value = formatError;
        isNicknameAvailable.value = false;
        return;
      }
    }

    isSubmitting.value = true;
    try {
      if (needsNickname) {
        await _profileRepository.updateNickname(nickname);
      }
      if (needsAgreement) {
        await _moderationRepository.agreeToEula();
      }

      // 마이페이지·작성자 표시가 새 닉네임을 곧바로 쓰도록 갱신한다.
      if (needsNickname && Get.isRegistered<MyInfoController>()) {
        await Get.find<MyInfoController>().loadProfile();
      }

      Get.back<bool>(result: true);
    } catch (e) {
      log('CommunityOnboardingController.submit error: $e');
      final message = communityErrorMessage(e);
      // 닉네임 중복/금칙어는 입력란 바로 아래에 붙여야 고칠 지점이 보인다.
      if (needsNickname && _isNicknameRejection(e)) {
        nicknameError.value = message;
        isNicknameAvailable.value = false;
      } else {
        Get.snackbar('저장 실패', message, snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 닉네임 자체가 거부된 경우인지 (중복 23505 / 금칙어 트리거).
  static bool _isNicknameRejection(Object error) {
    if (error is! PostgrestException) return false;
    return error.code == '23505' || error.hint == 'banned_word';
  }

  // ── 작성 게이트 ────────────────────────────────────────────────────────

  /// 글·댓글을 쓸 수 있는 상태인지 확인하고, 아니면 필요한 화면으로 유도한다.
  ///
  /// **반드시 작성 화면에 진입하기 전에 호출한다.** 제출 시점에 걸리면 서버가
  /// `cp_insert` 정책에서 42501 을 던지는데, 그때는 사용자가 이미 글을 다 쓴
  /// 뒤라 입력을 잃거나 원인을 알 수 없는 실패로 보인다.
  ///
  /// 반환값이 true 일 때만 작성 화면으로 넘어간다.
  static Future<bool> ensureCanWrite() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Get.toNamed<dynamic>(Routes.LOGIN);
      // 로그인 후 곧바로 작성 화면을 열지 않는다. 로그인 화면의 후속 흐름
      // (회원가입 전환 등)을 가로채지 않기 위해, 사용자가 FAB을 다시 누르게 한다.
      return false;
    }

    final moderationRepository = Get.find<CommunityModerationRepository>();

    CommunityWriteEligibility eligibility;
    bool agreed;
    try {
      eligibility = await moderationRepository.fetchWriteEligibility();
      agreed = await moderationRepository.hasAgreedToEula();
    } catch (e) {
      log('CommunityOnboardingController.ensureCanWrite error: $e');
      Get.snackbar(
        '잠시 후 다시 시도해주세요',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    // 이용 정지는 온보딩으로 풀 수 있는 문제가 아니다. 시트를 띄우면
    // 동의까지 마친 뒤 제출에서 42501 로 막혀 원인을 오해하게 된다.
    if (eligibility.isBanned) {
      Get.snackbar(
        '커뮤니티 이용이 제한되었습니다',
        '${_formatBanUntil(eligibility.bannedUntil!)}까지 글과 댓글을 작성할 수 없습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final needsNickname = eligibility.nickname == null;
    final needsAgreement = !agreed;
    if (!needsNickname && !needsAgreement) return true;

    final controller = Get.put(
      CommunityOnboardingController(
        needsNickname: needsNickname,
        needsAgreement: needsAgreement,
        initialNickname: eligibility.nickname,
      ),
    );
    // 금칙어 사전은 시트가 떠 있는 동안 백그라운드로 채운다.
    unawaited(controller.preloadBannedWords());

    try {
      final result = await Get.bottomSheet<bool>(
        const CommunityEulaSheet(),
        isScrollControlled: true,
        // 입력 도중 실수로 닫혀 처음부터 다시 하게 만들지 않는다.
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
      );
      return result == true;
    } finally {
      await Get.delete<CommunityOnboardingController>();
    }
  }

  static String _formatBanUntil(DateTime until) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${until.year}.${two(until.month)}.${two(until.day)} '
        '${two(until.hour)}:${two(until.minute)}';
  }
}
