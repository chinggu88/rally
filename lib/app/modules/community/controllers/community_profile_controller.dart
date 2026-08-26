import 'package:get/get.dart';

import '../../../data/models/public_profile_response.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../utils/community_error.dart';

/// 작성자 프로필 바텀시트 컨트롤러 — **보기 전용**이다.
///
/// 라우트가 없는 시트라 `Bindings` 클래스가 붙을 곳이 없다.
/// `CommunityProfileSheet.show()` 가 `Get.put` 으로 만들고 시트가 닫힐 때
/// `Get.delete` 로 정리한다.
///
/// 신고·차단은 여기서 다루지 않는다 — 기존 더보기(⋯) 시트
/// (`CommunityMoreSheet`)가 그 창구다. 그래서
/// `CommunityModerationRepository` 를 주입하지 않는다.
///
/// `onInit()` 에서 조회한다. `CommunityController` 의 "onInit 에서 fetch 하지
/// 않는다" 규칙은 `IndexedStack` 으로 항상 마운트되는 **탭 화면**에만 해당하고,
/// 이 시트는 사용자가 아바타를 눌러야 생성된다.
class CommunityProfileController extends GetxController {
  CommunityProfileController({
    required this.userId,
    this.fallbackNickname,
    this.fallbackAvatarUrl,
  });

  /// 조회 대상 사용자 UUID
  final String userId;

  /// 탭하기 직전 화면에 이미 떠 있던 닉네임 — 로딩 중 즉시 표시용
  final String? fallbackNickname;

  /// 탭하기 직전 화면에 이미 떠 있던 아바타 URL — 로딩 중 즉시 표시용
  final String? fallbackAvatarUrl;

  final ProfileRepository _profileRepository = Get.find<ProfileRepository>();

  /// 조회된 프로필 (null이면 미로드 또는 조회 실패)
  final _profile = Rxn<PublicProfileResponse>();
  PublicProfileResponse? get profile => _profile.value;

  /// 조회 로딩 상태
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  /// 에러 메시지 (null이면 정상 상태)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  /// 화면에 그릴 이름. 로드 전에는 폴백을 쓰고, 둘 다 없으면 null
  /// (위젯이 스켈레톤을 그린다).
  String? get displayName {
    final loaded = profile;
    if (loaded != null) return loaded.displayName;
    final fallback = fallbackNickname?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  /// 화면에 그릴 아바타 URL. 로드 전에는 폴백을 쓴다.
  String? get avatarUrl {
    final loaded = profile?.avatarUrl?.trim();
    if (loaded != null && loaded.isNotEmpty) return loaded;
    final fallback = fallbackAvatarUrl?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  /// 가입 시각 — 조회 전이거나 값이 없으면 null (위젯이 줄 자체를 숨긴다).
  DateTime? get joinedAt => profile?.createdAt;

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  /// 프로필 조회. 없는 사용자면 에러 문구로 안내한다.
  Future<void> fetchProfile() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      final result = await _profileRepository.fetchPublicProfile(userId);
      if (result == null) {
        _errorMessage.value = '사용자를 찾을 수 없습니다.';
      } else {
        _profile.value = result;
      }
    } catch (e) {
      _errorMessage.value = communityErrorMessage(e);
    } finally {
      _isLoading.value = false;
    }
  }
}
