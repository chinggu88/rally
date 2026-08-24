import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../utils/community_error.dart';
import '../../my_info/controllers/my_info_controller.dart';

/// 프로필 편집 화면 컨트롤러 — 닉네임/아바타 CRUD.
class ProfileEditController extends GetxController {
  final ProfileRepository _profileRepository = Get.find<ProfileRepository>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController nicknameController;

  /// 새로 선택한(아직 업로드 전) 로컬 이미지 파일.
  final Rxn<File> pickedImage = Rxn<File>();

  /// 현재 서버에 저장된 아바타 URL (미리보기 폴백).
  final RxnString currentAvatarUrl = RxnString();

  final _isSaving = false.obs;
  bool get isSaving => _isSaving.value;

  @override
  void onInit() {
    super.onInit();
    final my = Get.find<MyInfoController>();
    nicknameController = TextEditingController(text: my.nickname ?? '');
    currentAvatarUrl.value = my.avatarUrl;
  }

  @override
  void onClose() {
    nicknameController.dispose();
    super.onClose();
  }

  /// 갤러리에서 이미지 선택.
  Future<void> pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        pickedImage.value = File(picked.path);
      }
    } catch (e) {
      log('ProfileEditController.pickImage error: $e');
      Get.snackbar('사진 선택 실패', '잠시 후 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 아바타 제거 (선택한 로컬 이미지 + 서버 아바타 모두 비움).
  Future<void> removeAvatar() async {
    pickedImage.value = null;
    if (currentAvatarUrl.value == null) return;
    try {
      _isSaving.value = true;
      await _profileRepository.removeAvatar();
      currentAvatarUrl.value = null;
      await Get.find<MyInfoController>().loadProfile();
    } catch (e) {
      log('ProfileEditController.removeAvatar error: $e');
      Get.snackbar('삭제 실패', '잠시 후 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      _isSaving.value = false;
    }
  }

  /// 닉네임 길이 규격 (기획서 §5-5). 커뮤니티 온보딩 시트와 같은 값이어야
  /// 한다 — 한쪽에서만 통과하면 사용자가 규칙을 예측할 수 없다.
  static const int minNicknameLength = 2;
  static const int maxNicknameLength = 12;

  /// 닉네임 + (선택 시)아바타 업로드 저장.
  Future<void> save() async {
    final nickname = nicknameController.text.trim();
    if (nickname.isEmpty) {
      Get.snackbar('닉네임을 입력해주세요', '',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (nickname.length < minNicknameLength ||
        nickname.length > maxNicknameLength) {
      Get.snackbar(
        '닉네임 길이를 확인해주세요',
        '닉네임은 $minNicknameLength~$maxNicknameLength자로 입력해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      _isSaving.value = true;

      if (pickedImage.value != null) {
        await _profileRepository.uploadAvatar(pickedImage.value!);
      }
      await _profileRepository.updateNickname(nickname);

      // 마이페이지 상태 갱신
      await Get.find<MyInfoController>().loadProfile();

      Get.back<void>();
      Get.snackbar('저장 완료', '프로필이 업데이트되었습니다.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      // 닉네임 중복(23505)과 금칙어(hint='banned_word')는 사용자가 고칠 수 있는
      // 오류다. "잠시 후 다시 시도"로 덮으면 몇 번을 눌러도 같은 실패를 반복한다.
      // 서버 메시지 매핑은 커뮤니티와 공용(`communityErrorMessage`)이다 —
      // 닉네임 제약 자체가 커뮤니티 마이그레이션에서 온 것이라 문구가 같아야 한다.
      log('ProfileEditController.save error: $e');
      Get.snackbar('저장 실패', communityErrorMessage(e),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      _isSaving.value = false;
    }
  }
}
