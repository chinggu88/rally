import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/community_post_response.dart';
import '../../../data/repositories/community_post_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/community_error.dart';
import 'community_onboarding_controller.dart';
import 'community_post_detail_controller.dart';

/// 커뮤니티 탭 컨트롤러.
///
/// 뷰 `community_post_feed` 를 카테고리별로 조회해 최신순 목록을 노출하고,
/// `created_at` 커서 기반 무한 스크롤과 pull-to-refresh를 지원한다.
///
/// **`onInit()` 에서 로드하지 않는다.** `AppView` 의 `IndexedStack` 이 5개 탭을
/// 앱 시작 시 동시에 build 하므로, onInit에서 fetch하면 콜드 스타트마다 커뮤니티
/// 쿼리가 붙는다. 대신 `AppController.changeTab` 이 [loadIfNeeded] 를 호출해
/// 탭 최초 진입 시 1회만 로드한다.
class CommunityController extends GetxController {
  /// Singleton accessor
  static CommunityController get to => Get.find();

  /// 카테고리 코드 목록 — `null` 은 "전체"(필터 미적용)를 의미한다.
  static const List<String?> categories = <String?>[
    null,
    'free',
    'match',
    'gear',
    'partner',
  ];

  /// 카테고리 코드 → 한국어 라벨 (`PlayerController._categoryLabelsKo` 패턴).
  /// 라벨은 DB에 넣지 않고 클라이언트 상수로만 관리한다.
  static const Map<String, String> _categoryLabelsKo = <String, String>{
    'free': '자유',
    'match': '경기토론',
    'gear': '장비',
    'partner': '파트너찾기',
  };

  /// 카테고리 코드의 한국어 라벨. null이면 "전체".
  static String labelKoOf(String? code) {
    if (code == null) return '전체';
    return _categoryLabelsKo[code] ?? code;
  }

  /// 한 페이지에 가져올 게시글 수
  static const int pageSize = 20;

  final CommunityPostRepository _postRepository =
      Get.find<CommunityPostRepository>();

  /// 화면에 표시할 게시글 목록 (created_at 내림차순)
  final _posts = <CommunityPostResponse>[].obs;
  List<CommunityPostResponse> get posts => _posts;
  set posts(List<CommunityPostResponse> val) => _posts.assignAll(val);

  /// 첫 페이지 로딩 상태
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => _isLoading.value = val;

  /// 추가 페이지 로딩 상태 (첫 로드와 분리)
  final _isLoadingMore = false.obs;
  bool get isLoadingMore => _isLoadingMore.value;

  /// 다음 페이지 존재 여부
  final _hasMore = true.obs;
  bool get hasMore => _hasMore.value;

  /// 에러 메시지 (null이면 정상 상태)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => _errorMessage.value = val;

  /// 현재 선택된 카테고리 (null = 전체)
  final _selectedCategory = RxnString();
  String? get selectedCategory => _selectedCategory.value;
  set selectedCategory(String? val) => _selectedCategory.value = val;

  /// 진행 중인 첫 페이지 요청 토큰 (race condition 방지)
  int _inflightToken = 0;

  /// loadMore 전용 토큰 — 카테고리 변경/리프레시 시 증가시켜 진행 중이던
  /// loadMore 결과가 새 리스트에 잘못 append 되지 않도록 방어한다.
  int _loadMoreToken = 0;

  /// 탭 최초 진입 여부. 두 번째 진입부터는 목록과 스크롤을 그대로 유지한다.
  bool _hasLoadedOnce = false;

  /// 커뮤니티 탭 진입 시 호출 — 최초 1회만 첫 페이지를 로드한다.
  ///
  /// `PlayerController.reloadFromTab()` 처럼 매번 리셋하면 글을 읽다 다른 탭에
  /// 갔다 온 사용자의 스크롤 위치와 목록이 날아간다. 갱신은 pull-to-refresh로
  /// 사용자가 명시적으로 요청할 때만 한다.
  void loadIfNeeded() {
    if (_hasLoadedOnce) return;
    _hasLoadedOnce = true;
    fetchPosts();
  }

  /// 현재 `selectedCategory` 로 첫 페이지를 조회한다.
  /// 페이지 상태(`hasMore`)는 초기화된다.
  Future<void> fetchPosts() async {
    final targetCategory = selectedCategory;
    final token = ++_inflightToken;
    // 진행 중인 loadMore가 새 리스트에 결과를 append 하지 못하도록 무효화
    _loadMoreToken++;
    _hasMore.value = true;

    try {
      isLoading = true;
      errorMessage = null;

      final fetched = await _postRepository.listPosts(
        category: targetCategory,
        limit: pageSize,
      );

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _inflightToken) return;

      posts = fetched;
      _hasMore.value = fetched.length >= pageSize;
    } catch (e) {
      if (token != _inflightToken) return;
      log('CommunityController.fetchPosts error: $e');
      errorMessage = communityErrorMessage(e);
      posts = const <CommunityPostResponse>[];
      _hasMore.value = false;
    } finally {
      if (token == _inflightToken) {
        isLoading = false;
      }
    }
  }

  /// 다음 페이지를 마지막 게시글의 `created_at` 커서로 조회해 append 한다.
  ///
  /// 실패는 silent — `hasMore` 를 유지해 다음 스크롤에서 자연 재시도된다
  /// (`PlayerController.loadMore` 정책).
  Future<void> loadMore() async {
    if (_isLoadingMore.value) return;
    if (!_hasMore.value) return;
    if (_isLoading.value) return;
    if (errorMessage != null) return;

    final cursor = _posts.isEmpty ? null : _posts.last.createdAt;
    if (cursor == null) return;

    final fetchTokenAtStart = _inflightToken;
    final myToken = ++_loadMoreToken;
    final targetCategory = selectedCategory;

    _isLoadingMore.value = true;
    try {
      final fetched = await _postRepository.listPosts(
        category: targetCategory,
        before: cursor,
        limit: pageSize,
      );

      // 가드: 그 사이 fetchPosts(카테고리 변경/리프레시)가 발생했으면 무시
      if (fetchTokenAtStart != _inflightToken) return;
      if (myToken != _loadMoreToken) return;

      if (fetched.isNotEmpty) {
        _posts.addAll(fetched);
      }
      _hasMore.value = fetched.length >= pageSize;
    } catch (e) {
      log('CommunityController.loadMore error: $e');
      // silent: hasMore 유지 → 다음 스크롤에서 자연스럽게 재시도 가능
    } finally {
      if (myToken == _loadMoreToken) {
        _isLoadingMore.value = false;
      }
    }
  }

  /// Pull-to-refresh / 재시도 버튼용 — 현재 카테고리로 첫 페이지를 다시 부른다.
  Future<void> refreshPosts() async {
    await fetchPosts();
  }

  /// 카테고리를 변경하고 목록을 다시 불러온다. 동일 카테고리 재선택은 no-op.
  Future<void> changeCategory(String? category) async {
    if (category == selectedCategory) return;
    if (!categories.contains(category)) {
      log('CommunityController.changeCategory: unsupported category=$category');
      return;
    }
    selectedCategory = category;
    // 카테고리를 바꾸면 목록을 비워 로딩 인디케이터가 즉시 보이도록 한다.
    posts = const <CommunityPostResponse>[];
    await fetchPosts();
  }

  /// 현재 카테고리에 맞는 빈 상태 문구.
  /// 파트너찾기는 조회 대신 작성을 유도한다(초기 트래픽 진입점).
  String get emptyStateMessage {
    switch (selectedCategory) {
      case 'partner':
        return '아직 모집 글이 없습니다.\n첫 파트너 모집 글을 올려보세요.';
      case 'gear':
        return '아직 장비 이야기가 없습니다.\n첫 후기를 남겨보세요.';
      case 'match':
        return '아직 경기 토론이 없습니다.\n오늘 본 경기를 이야기해보세요.';
      case 'free':
        return '아직 글이 없습니다.\n첫 글을 남겨보세요.';
      default:
        return '아직 게시글이 없습니다.\n첫 글의 주인공이 되어보세요.';
    }
  }

  /// 글쓰기 FAB — 작성 자격을 먼저 통과시킨 뒤 작성 화면으로 전이한다.
  ///
  /// 게이트를 **화면 진입 전에** 통과시키는 것이 핵심이다. 제출 시점에 확인하면
  /// 서버 `cp_insert` 정책에서 42501 이 나는데, 그때는 사용자가 이미 글을 다
  /// 써 버린 뒤다.
  Future<void> openCompose() async {
    if (!await CommunityOnboardingController.ensureCanWrite()) return;

    final created = await Get.toNamed<dynamic>(Routes.COMMUNITY_COMPOSE);
    // 새 글은 최신순 목록의 최상단이라 첫 페이지만 다시 받으면 된다.
    if (created == true) await refreshPosts();
  }

  /// 게시글 카드 탭 — 상세 화면으로 전이한다.
  void openPostDetail(CommunityPostResponse post) {
    final id = post.id;
    if (id == null || id.isEmpty) {
      log('CommunityController.openPostDetail: missing id');
      return;
    }
    Get.toNamed<dynamic>(
      Routes.COMMUNITY_POST_DETAIL,
      arguments: <String, dynamic>{CommunityPostDetailController.argPostId: id},
    );
  }

  /// 상세 화면에서 갱신된 게시글을 목록에 되반영한다.
  ///
  /// 좋아요·조회수는 상세에서 바뀌므로 뒤로가기 시 목록도 같은 값을 보여야 한다.
  /// **요소를 교체**해야 한다 — 기존 인스턴스의 필드를 setter로 바꾸면
  /// `RxList` 가 요소 동일성 때문에 변경을 감지하지 못한다.
  void applyPostUpdate(CommunityPostResponse updated) {
    final id = updated.id;
    if (id == null || id.isEmpty) return;
    final index = _posts.indexWhere((p) => p.id == id);
    if (index < 0) return;
    _posts[index] = updated;
  }

  /// 상세에서 삭제된 게시글을 목록에서 제거한다.
  void removePost(String id) {
    if (id.isEmpty) return;
    _posts.removeWhere((p) => p.id == id);
  }
}
