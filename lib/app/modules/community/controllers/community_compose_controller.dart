import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/community_post_response.dart';
import '../../../data/models/create_community_post_parameter.dart';
import '../../../data/models/update_community_post_parameter.dart';
import '../../../data/repositories/community_moderation_repository.dart';
import '../../../data/repositories/community_post_repository.dart';
import '../../../utils/community_error.dart';
import '../../../utils/community_text_filter.dart';
import 'community_controller.dart';

/// 커뮤니티 글 작성 / 수정 겸용 컨트롤러 (기획서 S-3).
///
/// arguments 에 [argPostId] 가 있으면 수정 모드다. 작성과 수정은 검증·이미지
/// 처리·에러 매핑이 거의 같아서 화면을 나누면 그 로직이 통째로 중복된다.
///
/// **작성 자격(로그인·닉네임·약관)은 여기서 확인하지 않는다.**
/// `CommunityOnboardingController.ensureCanWrite()` 가 화면 진입 *전에* 통과
/// 시킨다 — 제출 시점에 걸리면 다 쓴 글을 잃는다.
class CommunityComposeController extends GetxController {
  /// arguments 키 — 있으면 수정 모드 (`community_posts.id`)
  static const String argPostId = 'post_id';

  /// 작성 모드 기본 카테고리 — 서버 CHECK 제약의 `free`(자유)다.
  static const String defaultCategory = 'free';

  /// 서버 CHECK 제약과 같은 값 (`community_posts`)
  static const int maxTitleLength = 100;
  static const int maxContentLength = 5000;

  /// 게시글당 이미지 최대 장수
  static const int maxImages = CommunityPostRepository.maxImageCount;

  /// 이미지 리사이즈 규격 — 5MB 버킷 제한 안에 들어오게 미리 줄인다.
  static const double _imageMaxWidth = 1600;
  static const int _imageQuality = 80;

  final CommunityPostRepository _postRepository =
      Get.find<CommunityPostRepository>();
  final CommunityModerationRepository _moderationRepository =
      Get.find<CommunityModerationRepository>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController titleController;
  late final TextEditingController contentController;

  /// 선택된 카테고리 (`free` / `match` / `gear` / `partner`). null이면 미선택.
  final selectedCategory = RxnString();

  /// 아직 업로드하지 않은 로컬 이미지. **제출 시점에만 업로드**한다 —
  /// 작성을 취소하면 스토리지에 아무것도 남지 않는다(고아 파일 원천 차단).
  final pickedImages = <File>[].obs;

  /// 수정 모드에서 유지하기로 한 기존 이미지 경로. 사용자가 X로 지우면
  /// 여기서만 빠지고, 실제 스토리지 삭제는 UPDATE 성공 뒤에 한다.
  final existingImagePaths = <String>[].obs;

  final isSubmitting = false.obs;

  /// 수정 모드 초기 로딩
  final isLoadingPost = false.obs;

  /// 원본 조회 실패 문구 (수정 모드)
  final loadError = RxnString();

  /// 글자 수 카운터용 — TextEditingController 를 Obx 로 직접 감시할 수 없어
  /// onChanged 에서 갱신한다.
  final titleLength = 0.obs;
  final contentLength = 0.obs;

  /// 이미지 경로의 `{draft_id}` 세그먼트.
  ///
  /// `uuid` 패키지를 새로 넣지 않는다 — lock 에만 있는 전이 의존성이고, 경로가
  /// 이미 `{uid}/` 로 스코프되어 있어 전역 유일성이 필요 없다. 같은 사용자가
  /// 같은 마이크로초에 두 번 작성을 시작할 수는 없다.
  late final String draftId;

  String? _postId;
  String? get postId => _postId;
  bool get isEditMode => _postId != null;

  /// 수정 전 이미지 경로 원본. UPDATE 성공 후 "빠진 것"을 계산하는 기준이다.
  List<String> _originalImagePaths = const <String>[];

  /// 클라이언트 금칙어 사전. 로딩 실패 시 빈 목록 — 서버 트리거가 최종 권위라
  /// 사전 검증이 없어도 잘못된 글이 저장되지는 않는다.
  List<String> _bannedWords = const <String>[];

  /// 현재 첨부 총 장수 (기존 유지분 + 새로 고른 것)
  int get totalImageCount => existingImagePaths.length + pickedImages.length;

  /// 더 붙일 수 있는 장수
  int get remainingImageSlots => maxImages - totalImageCount;

  @override
  void onInit() {
    super.onInit();
    draftId = DateTime.now().microsecondsSinceEpoch.toString();
    titleController = TextEditingController();
    contentController = TextEditingController();

    _readArguments();
    _preloadBannedWords();

    if (isEditMode) {
      _loadOriginalPost();
    } else {
      // 목록에서 특정 카테고리를 보던 중이면 그 카테고리로 시작한다.
      // "전체"를 보고 있었으면 목록 쪽 값이 null 이라 아무것도 선택되지 않는데,
      // 그러면 등록 버튼을 누르고 나서야 "카테고리를 선택해주세요."를 만난다.
      // 그래서 미선택 대신 [defaultCategory]("자유")로 시작한다.
      // 딥링크 등으로 목록을 거치지 않고 들어온 경우도 같다.
      selectedCategory.value =
          Get.isRegistered<CommunityController>()
              ? (CommunityController.to.selectedCategory ?? defaultCategory)
              : defaultCategory;
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    contentController.dispose();
    super.onClose();
  }

  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final id = (args[argPostId] as String?)?.trim();
      if (id != null && id.isNotEmpty) _postId = id;
    } else if (args is String && args.trim().isNotEmpty) {
      _postId = args.trim();
    }
  }

  Future<void> _preloadBannedWords() async {
    try {
      _bannedWords = await _moderationRepository.fetchBannedWords();
    } catch (e) {
      // 사용자가 요청하지 않은 백그라운드 작업이므로 로그만 남긴다(§9-J).
      log('CommunityComposeController._preloadBannedWords error: $e');
    }
  }

  /// 수정 모드 — 원본을 서버에서 다시 받아 폼을 채운다.
  ///
  /// 목록/상세가 들고 있는 인스턴스를 넘겨받지 않는 이유는, 그 사이 다른
  /// 기기에서 수정됐을 수 있어서다. 오래된 본문 위에 덮어쓰면 변경이 사라진다.
  Future<void> _loadOriginalPost() async {
    final id = _postId;
    if (id == null) return;

    isLoadingPost.value = true;
    loadError.value = null;
    try {
      final post = await _postRepository.fetchById(id);
      if (post == null) {
        loadError.value = '삭제되었거나 볼 수 없는 게시글입니다.';
        return;
      }
      _applyPost(post);
    } catch (e) {
      log('CommunityComposeController._loadOriginalPost error: $e');
      loadError.value = communityErrorMessage(e);
    } finally {
      isLoadingPost.value = false;
    }
  }

  void _applyPost(CommunityPostResponse post) {
    selectedCategory.value = post.category;
    titleController.text = post.title ?? '';
    contentController.text = post.content ?? '';
    titleLength.value = titleController.text.runes.length;
    contentLength.value = contentController.text.runes.length;
    _originalImagePaths = List<String>.unmodifiable(
      post.imagePaths ?? const <String>[],
    );
    existingImagePaths.assignAll(_originalImagePaths);
  }

  /// 재시도 (수정 모드 원본 조회 실패 시)
  Future<void> retryLoad() => _loadOriginalPost();

  void onTitleChanged(String value) => titleLength.value = value.runes.length;

  void onContentChanged(String value) =>
      contentLength.value = value.runes.length;

  void selectCategory(String category) => selectedCategory.value = category;

  /// 갤러리에서 이미지 선택 (최대 [maxImages] 장).
  Future<void> pickImages() async {
    final remaining = remainingImageSlots;
    if (remaining <= 0) {
      Get.snackbar(
        '이미지 첨부',
        '이미지는 최대 $maxImages장까지 첨부할 수 있습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final picked = await _picker.pickMultiImage(
        limit: remaining,
        maxWidth: _imageMaxWidth,
        imageQuality: _imageQuality,
      );
      if (picked.isEmpty) return;

      // `limit` 을 무시하는 플랫폼/OS 버전이 있어 여기서 한 번 더 자른다.
      final accepted = <File>[];
      var oversized = 0;
      for (final xfile in picked.take(remaining)) {
        final file = File(xfile.path);
        if (await file.length() > CommunityPostRepository.maxImageBytes) {
          oversized++;
          continue;
        }
        accepted.add(file);
      }

      if (accepted.isNotEmpty) pickedImages.addAll(accepted);

      // 용량 초과는 업로드 시점이 아니라 고른 즉시 알려야 원인을 안다.
      if (oversized > 0) {
        Get.snackbar(
          '첨부하지 못한 이미지',
          '5MB를 넘는 이미지 $oversized장은 제외했습니다.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else if (picked.length > remaining) {
        Get.snackbar(
          '이미지 첨부',
          '이미지는 최대 $maxImages장까지 첨부할 수 있습니다.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      log('CommunityComposeController.pickImages error: $e');
      Get.snackbar(
        '사진 선택 실패',
        '잠시 후 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 새로 고른 이미지 제거 (아직 업로드 전이라 스토리지 작업이 없다).
  void removeImage(int index) {
    if (index < 0 || index >= pickedImages.length) return;
    pickedImages.removeAt(index);
  }

  /// 수정 모드에서 기존 이미지 제거 — 목록에서만 빼고 실제 삭제는 유예한다.
  /// UPDATE 가 실패했는데 파일을 먼저 지우면 이미지가 증발한다.
  void removeExistingImage(int index) {
    if (index < 0 || index >= existingImagePaths.length) return;
    existingImagePaths.removeAt(index);
  }

  /// 작성 중 내용이 있는지 — 뒤로가기 확인 다이얼로그 노출 조건.
  bool get hasUnsavedInput {
    if (isEditMode) {
      return titleController.text.trim().isNotEmpty ||
          contentController.text.trim().isNotEmpty;
    }
    return selectedCategory.value != null ||
        titleController.text.trim().isNotEmpty ||
        contentController.text.trim().isNotEmpty ||
        pickedImages.isNotEmpty;
  }

  /// 등록 / 수정 완료.
  ///
  /// 고아 파일 방지 순서를 엄수한다:
  ///   ① 이미지 업로드 → ② INSERT/UPDATE → ③ ②가 실패하면 ①을 되돌린다.
  /// 수정 시 교체는 **업로드 → UPDATE 성공 → 옛 path 삭제** 순서다. 반대로
  /// 하면 UPDATE 실패 시 이미 지운 이미지를 되돌릴 방법이 없다.
  Future<void> submit() async {
    if (isSubmitting.value) return;

    final category = selectedCategory.value;
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    final validationError = _validate(
      category: category,
      title: title,
      content: content,
    );
    if (validationError != null) {
      Get.snackbar(
        isEditMode ? '수정 실패' : '등록 실패',
        validationError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSubmitting.value = true;
    try {
      if (isEditMode) {
        await _submitUpdate(category!, title, content);
      } else {
        await _submitCreate(category!, title, content);
      }
    } catch (e) {
      log('CommunityComposeController.submit error: $e');
      Get.snackbar(
        isEditMode ? '수정 실패' : '등록 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _submitCreate(
    String category,
    String title,
    String content,
  ) async {
    final uploaded = await _postRepository.uploadImages(
      draftId,
      pickedImages.toList(),
    );

    try {
      await _postRepository.createPost(
        CreateCommunityPostParameter(
          category: category,
          title: title,
          content: content,
          imagePaths: uploaded,
        ),
      );
    } catch (e) {
      // 글이 생기지 않았으므로 방금 올린 파일은 아무도 참조하지 않는다.
      await _postRepository.removeImages(uploaded);
      rethrow;
    }

    Get.back<bool>(result: true);
    Get.snackbar('등록 완료', '게시글을 등록했습니다.', snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _submitUpdate(
    String category,
    String title,
    String content,
  ) async {
    final id = _postId!;
    final keptPaths = existingImagePaths.toList();

    final uploaded = await _postRepository.uploadImages(
      draftId,
      pickedImages.toList(),
    );

    try {
      await _postRepository.updatePost(
        id,
        UpdateCommunityPostParameter(
          category: category,
          title: title,
          content: content,
          imagePaths: [...keptPaths, ...uploaded],
          // edited_at 은 보내지 않는다 — 서버 트리거가 찍는다.
        ),
      );
    } catch (e) {
      // UPDATE 가 실패했으니 원본은 옛 이미지를 그대로 참조한다.
      // 되돌릴 것은 방금 올린 새 파일뿐이다.
      await _postRepository.removeImages(uploaded);
      rethrow;
    }

    // 여기서부터는 성공 확정. 참조가 끊긴 옛 이미지를 정리한다.
    // removeImages 는 실패해도 던지지 않는다 — 뒷정리 실패로 "수정 실패"를
    // 띄우면 사용자에게 거짓말이 된다.
    final removed =
        _originalImagePaths.where((p) => !keptPaths.contains(p)).toList();
    await _postRepository.removeImages(removed);

    Get.back<bool>(result: true);
    Get.snackbar('수정 완료', '게시글을 수정했습니다.', snackPosition: SnackPosition.BOTTOM);
  }

  /// 제출 전 클라이언트 검증. 통과하면 null.
  ///
  /// 길이 제한은 서버 CHECK 와 같은 값이라 여기서 막으면 왕복이 줄고,
  /// 금칙어는 서버 트리거가 최종 권위이므로 여기서는 즉시 피드백만 담당한다.
  String? _validate({
    required String? category,
    required String title,
    required String content,
  }) {
    if (category == null || category.isEmpty) {
      return '카테고리를 선택해주세요.';
    }
    if (title.isEmpty) return '제목을 입력해주세요.';
    if (title.runes.length > maxTitleLength) {
      return '제목은 $maxTitleLength자를 넘을 수 없습니다.';
    }
    if (content.isEmpty) return '본문을 입력해주세요.';
    if (content.runes.length > maxContentLength) {
      return '본문은 $maxContentLength자를 넘을 수 없습니다.';
    }
    if (totalImageCount > maxImages) {
      return '이미지는 최대 $maxImages장까지 첨부할 수 있습니다.';
    }
    final banned = CommunityTextFilter.findBannedWordInPost(
      title: title,
      content: content,
      bannedNorms: _bannedWords,
    );
    if (banned != null) {
      return '사용할 수 없는 표현이 포함되어 있습니다.';
    }
    return null;
  }
}
