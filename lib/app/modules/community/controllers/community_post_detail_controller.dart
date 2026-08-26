import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/community_comment_response.dart';
import '../../../data/models/community_post_response.dart';
import '../../../data/models/create_community_comment_parameter.dart';
import '../../../data/models/create_community_report_parameter.dart';
import '../../../data/repositories/community_comment_repository.dart';
import '../../../data/repositories/community_moderation_repository.dart';
import '../../../data/repositories/community_post_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/community_error.dart';
import '../../../utils/community_text_filter.dart';
import '../views/widgets/community_more_sheet.dart';
import '../views/widgets/community_profile_sheet.dart';
import '../views/widgets/community_report_sheet.dart';
import 'community_compose_controller.dart';
import 'community_controller.dart';
import 'community_onboarding_controller.dart';

/// 커뮤니티 게시글 상세 화면 컨트롤러.
///
/// 목록에서 넘어온 `post_id` 로 뷰 `community_post_feed` 를 1행 조회하고,
/// 좋아요 토글 · 조회수 집계 · 본인 글 삭제 · 댓글/대댓글을 담당한다.
///
/// 댓글용 컨트롤러를 따로 두지 않는다 — 댓글 작성/삭제가 게시글의
/// `comment_count` 를 곧바로 바꾸고, 그 값이 다시 목록 카드까지 전파돼야 해서
/// 두 상태를 한 곳에서 들고 있는 편이 동기화 경로가 짧다.
///
/// 목록과의 동기화는 [CommunityController] 의 리스트 요소를 **교체**하는 방식이다.
/// 상세에서 바뀐 좋아요/조회수/삭제가 뒤로가기 즉시 목록에 보여야 하는데,
/// 두 화면이 같은 인스턴스를 공유하지 않으므로(상세는 서버에서 새로 받아온다)
/// 갱신된 인스턴스를 목록에 밀어 넣어 준다.
class CommunityPostDetailController extends GetxController {
  /// arguments 키 — 상세 조회 대상 `community_posts.id` (uuid)
  static const String argPostId = 'post_id';

  final CommunityPostRepository _postRepository =
      Get.find<CommunityPostRepository>();

  /// 조회된 게시글 (null이면 미로드 또는 조회 실패)
  final _post = Rxn<CommunityPostResponse>();
  CommunityPostResponse? get post => _post.value;
  set post(CommunityPostResponse? val) => _post.value = val;

  /// 첫 조회 로딩 상태
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => _isLoading.value = val;

  /// 에러 메시지 (null이면 정상 상태)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => _errorMessage.value = val;

  /// 좋아요 요청 진행 중 여부 (연타 방지)
  final _isTogglingLike = false.obs;
  bool get isTogglingLike => _isTogglingLike.value;

  /// 삭제 요청 진행 중 여부
  final _isDeleting = false.obs;
  bool get isDeleting => _isDeleting.value;

  /// 상세 조회 대상 id
  String? _postId;
  String? get postId => _postId;

  /// 조회수 RPC 호출 여부. 화면 생명주기당 1회만 호출한다
  /// (1인 1회 판정 자체는 서버가 `community_post_views` 로 보장한다).
  bool _viewCounted = false;

  /// 현재 로그인 사용자 id — 비로그인이면 null
  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  /// 본인이 쓴 글인지 여부. 더보기(⋯) 노출 조건이다.
  bool get isMine {
    final authorId = post?.authorId;
    final uid = _currentUserId;
    if (authorId == null || uid == null) return false;
    return authorId == uid;
  }

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    loadPost();
    // 댓글은 게시글 조회와 독립이다. 순차로 기다리면 본문이 뜬 뒤에도
    // 댓글 자리가 한참 비어 있게 되므로 같이 출발시킨다.
    loadComments();
    _preloadBannedWords();
    _loadAdminFlag();
  }

  @override
  void onClose() {
    commentInput.dispose();
    commentFocusNode.dispose();
    super.onClose();
  }

  /// 네비게이션 arguments 파싱 — Map을 기대하되 문자열 단독 전달도 받아준다.
  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      _postId = (args[argPostId] as String?)?.trim();
    } else if (args is String) {
      _postId = args.trim();
    }
  }

  /// 게시글을 조회한다. 성공하면 이어서 조회수를 1회 집계한다.
  Future<void> loadPost() async {
    final id = _postId;
    if (id == null || id.isEmpty) {
      errorMessage = '게시글을 찾을 수 없습니다.';
      isLoading = false;
      return;
    }

    try {
      isLoading = true;
      errorMessage = null;

      final fetched = await _postRepository.fetchById(id);
      if (fetched == null) {
        // 뷰가 security_invoker 라 삭제·숨김·차단 글은 0행으로 돌아온다.
        post = null;
        errorMessage = '삭제되었거나 볼 수 없는 게시글입니다.';
        return;
      }

      post = fetched;
      _syncToList(fetched);
    } catch (e) {
      log('CommunityPostDetailController.loadPost error: $e');
      post = null;
      errorMessage = communityErrorMessage(e);
    } finally {
      isLoading = false;
    }
    await _countViewOnce();
  }

  /// 재시도 버튼용.
  Future<void> refreshPost() async {
    await loadPost();
  }

  /// 조회수 집계 — 화면당 1회.
  ///
  /// 실패는 **silent** 다. 읽는 도중 스낵바가 화면을 덮는 손해가
  /// 카운터 1 누락보다 크다 (`CommunityController.loadMore` 와 같은 정책).
  Future<void> _countViewOnce() async {
    if (_viewCounted) return;
    final current = post;
    final id = current?.id;
    if (current == null || id == null || id.isEmpty) return;
    _viewCounted = true;

    try {
      final updated = await _postRepository.incrementView(id);
      if (updated == null) return;
      final latest = post;
      if (latest == null || latest.id != id) return;
      final next = latest.copyWithViewCount(updated);
      post = next;
      _syncToList(next);
    } catch (e) {
      log('CommunityPostDetailController._countViewOnce error: $e');
    }
  }

  /// 좋아요 토글 — 낙관적 업데이트 후 실패 시 롤백.
  ///
  /// `copyWithLike` 로 새 인스턴스를 만들어 대입한다. setter로 필드만 바꾸면
  /// `Rxn`/`RxList` 가 요소 동일성 때문에 변경을 감지하지 못한다.
  Future<void> toggleLike() async {
    final current = post;
    final id = current?.id;
    if (current == null || id == null || id.isEmpty) return;

    if (_currentUserId == null) {
      Get.toNamed<dynamic>(Routes.LOGIN);
      return;
    }
    if (_isTogglingLike.value) return;

    final wasLiked = current.isLiked == true;
    final baseCount = current.likeCount ?? 0;
    final optimistic = current.copyWithLike(
      likeCount: wasLiked ? (baseCount > 0 ? baseCount - 1 : 0) : baseCount + 1,
      isLiked: !wasLiked,
    );
    post = optimistic;
    _syncToList(optimistic);

    _isTogglingLike.value = true;
    try {
      if (wasLiked) {
        await _postRepository.unlikePost(id);
      } else {
        await _postRepository.likePost(id);
      }
    } catch (e) {
      // 롤백 + 안내.
      //
      // 기획서 §9-J의 "좋아요 실패는 silent" 정책은 목록에서 스크롤 중
      // 우발적으로 눌린 경우와 조회수 같은 백그라운드 부수효과를 겨냥한 것이다.
      // 상세 화면의 좋아요는 사용자가 하트를 의도적으로 누른 명시적 액션이라,
      // 아무 설명 없이 하트만 되돌아가면 원인을 알 수 없다. 여기서는 알린다.
      log('CommunityPostDetailController.toggleLike error: $e');
      post = current;
      _syncToList(current);
      Get.snackbar(
        wasLiked ? '좋아요 취소 실패' : '좋아요 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isTogglingLike.value = false;
    }
  }

  /// 본인 글 수정 — 작성 게이트를 통과시킨 뒤 작성 화면을 수정 모드로 연다.
  ///
  /// 이미 글을 쓴 적이 있는 사용자라도 게이트를 건너뛰지 않는다. 약관 버전이
  /// 올라갔거나(`community_eula_version()` 변경) 이용 정지를 받았을 수 있고,
  /// 그때 UPDATE 는 42501 로 막힌다.
  Future<void> openEdit() async {
    final id = post?.id;
    if (id == null || id.isEmpty) return;
    if (!isMine) return;
    if (!await CommunityOnboardingController.ensureCanWrite()) return;

    final updated = await Get.toNamed<dynamic>(
      Routes.COMMUNITY_COMPOSE,
      arguments: <String, dynamic>{CommunityComposeController.argPostId: id},
    );
    // 수정 결과(제목·본문·이미지·"수정됨" 표시)를 서버에서 다시 받아 반영한다.
    // loadPost가 목록 동기화(_syncToList)까지 함께 처리한다.
    if (updated == true) await loadPost();
  }

  /// 본인 글 삭제 확인 다이얼로그 → [deletePost].
  Future<void> confirmDeletePost() async {
    final confirmed = await Get.dialog<bool>(
      _buildConfirmDialog(
        title: '게시글 삭제',
        message: '삭제한 게시글은 복구할 수 없습니다.\n삭제하시겠습니까?',
        confirmLabel: '삭제',
        danger: true,
      ),
    );
    if (confirmed == true) await deletePost();
  }

  /// 본인 글 삭제 (소프트 삭제 RPC).
  ///
  /// 명시적 액션이므로 실패 시에는 스낵바로 알린다.
  Future<void> deletePost() async {
    final id = post?.id;
    if (id == null || id.isEmpty) return;
    if (!isMine) return;
    if (_isDeleting.value) return;

    _isDeleting.value = true;
    try {
      await _postRepository.deletePost(id);
      _removeFromList(id);
      Get.back<void>();
      Get.snackbar(
        '삭제 완료',
        '게시글을 삭제했습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('CommunityPostDetailController.deletePost error: $e');
      Get.snackbar(
        '삭제 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isDeleting.value = false;
    }
  }

  /// 갱신된 게시글을 목록 컨트롤러에 되반영한다.
  /// 목록 탭이 아직 등록되지 않았거나(딥링크 진입) 해당 글이 현재 목록에
  /// 없으면 아무 일도 하지 않는다.
  void _syncToList(CommunityPostResponse updated) {
    if (!Get.isRegistered<CommunityController>()) return;
    CommunityController.to.applyPostUpdate(updated);
  }

  /// 삭제된 게시글을 목록에서 제거한다.
  void _removeFromList(String id) {
    if (!Get.isRegistered<CommunityController>()) return;
    CommunityController.to.removePost(id);
  }

  // ── 댓글 · 대댓글 ──────────────────────────────────────────────────────

  final CommunityCommentRepository _commentRepository =
      Get.find<CommunityCommentRepository>();
  final CommunityModerationRepository _moderationRepository =
      Get.find<CommunityModerationRepository>();

  /// 서버에서 받은 댓글 원본 (created_at ASC). 화면 배치는 [threadedComments].
  final _comments = RxList<CommunityCommentResponse>();
  List<CommunityCommentResponse> get comments => _comments;

  /// 댓글 첫 조회 로딩 상태
  final _isCommentsLoading = false.obs;
  bool get isCommentsLoading => _isCommentsLoading.value;

  /// 댓글 조회 에러 (null이면 정상)
  final _commentsError = RxnString();
  String? get commentsError => _commentsError.value;

  /// 답글 대상. null이면 최상위 댓글을 쓰는 중이다.
  final _replyTarget = Rxn<CommunityCommentResponse>();
  CommunityCommentResponse? get replyTarget => _replyTarget.value;

  /// 댓글 등록 진행 중 (연타 방지 + 전송 버튼 인디케이터)
  final _isSubmittingComment = false.obs;
  bool get isSubmittingComment => _isSubmittingComment.value;

  /// 삭제 진행 중인 댓글 id. 같은 댓글의 중복 삭제를 막는다.
  final _deletingCommentId = RxnString();
  String? get deletingCommentId => _deletingCommentId.value;

  /// 입력 길이 — 전송 버튼 활성 판정용 (`CommunityComposeController` 와 동일 패턴).
  final commentLength = 0.obs;

  final TextEditingController commentInput = TextEditingController();
  final FocusNode commentFocusNode = FocusNode();

  /// 클라이언트 금칙어 사전. 로딩 실패 시 빈 목록 — 서버 트리거가 최종 권위라
  /// 사전 검증이 없어도 잘못된 댓글이 저장되지는 않는다.
  List<String> _bannedWords = const <String>[];

  /// 화면에 그릴 순서로 평탄화한 댓글 목록.
  ///
  /// 규칙 세 가지가 여기서 결정된다:
  ///
  /// 1. **고아 대댓글은 드롭한다.** 부모 댓글 작성자를 차단하면 RLS 가 부모
  ///    행만 걸러내므로 대댓글이 최상위로 튀어나온다. `parent_id` 가 조회
  ///    결과에 없으면 렌더하지 않는다.
  /// 2. **툼스톤은 필요할 때만 남긴다.** 삭제·숨김 댓글의 행이 내려오는 이유는
  ///    대댓글의 부모 자리를 지키기 위해서다. 보여줄 자식이 없으면 "삭제된
  ///    댓글입니다"만 덩그러니 남을 이유가 없으므로 목록에서 뺀다.
  ///    (본인이 방금 지운 댓글은 RLS 상 자기에게만 계속 보인다.)
  /// 3. 대댓글은 1depth 뿐이라 재귀가 필요 없다 — 부모 바로 뒤에 붙인다.
  List<CommunityCommentResponse> get threadedComments {
    final all = _comments;
    if (all.isEmpty) return const <CommunityCommentResponse>[];

    final byId = <String, CommunityCommentResponse>{};
    for (final comment in all) {
      final id = comment.id;
      if (id != null && id.isNotEmpty) byId[id] = comment;
    }

    final roots = <CommunityCommentResponse>[];
    final childrenOf = <String, List<CommunityCommentResponse>>{};
    for (final comment in all) {
      final parentId = comment.parentId;
      if (parentId == null || parentId.isEmpty) {
        roots.add(comment);
        continue;
      }
      // 부모가 목록에 없다 = 차단 등으로 걸러졌다. 고아는 그리지 않는다.
      if (!byId.containsKey(parentId)) continue;
      // 삭제된 대댓글은 자식을 가질 수 없으므로 툼스톤을 남길 이유가 없다.
      if (comment.isRemoved) continue;
      (childrenOf[parentId] ??= <CommunityCommentResponse>[]).add(comment);
    }

    final result = <CommunityCommentResponse>[];
    for (final root in roots) {
      final id = root.id;
      final children =
          (id == null ? null : childrenOf[id]) ??
          const <CommunityCommentResponse>[];
      if (root.isRemoved && children.isEmpty) continue;
      result.add(root);
      result.addAll(children);
    }
    return result;
  }

  /// 목록에 실제로 그려지는 댓글 수 (툼스톤 제외).
  ///
  /// 하단 액션바의 숫자(`post.commentCount`)와 다를 수 있다. 카운터는 서버
  /// 트리거가 전체 기준으로 세고 이 값은 차단 필터를 통과한 것만 세기 때문이며,
  /// 의도된 차이라 억지로 맞추지 않는다.
  int get visibleCommentCount =>
      threadedComments.where((c) => !c.isRemoved).length;

  /// 본인이 쓴 댓글인지 — 롱프레스 삭제 노출 조건.
  bool isMyComment(CommunityCommentResponse comment) {
    final authorId = comment.authorId;
    final uid = _currentUserId;
    if (authorId == null || uid == null) return false;
    return authorId == uid;
  }

  /// 답글을 달 수 있는 댓글인지. 서버 트리거(`depth_exceeded` / `parent_removed`)와
  /// 같은 조건을 UI 에서 먼저 막아 왕복을 줄인다.
  bool canReplyTo(CommunityCommentResponse comment) =>
      !comment.isRemoved && !comment.isReply;

  Future<void> _preloadBannedWords() async {
    try {
      _bannedWords = await _moderationRepository.fetchBannedWords();
    } catch (e) {
      // 사용자가 요청하지 않은 백그라운드 작업이라 로그만 남긴다(§9-J).
      log('CommunityPostDetailController._preloadBannedWords error: $e');
    }
  }

  /// 댓글 목록 조회.
  ///
  /// 페이지네이션 없이 전량을 받는다 — 부분 로딩을 하면 "아직 못 받은 부모"와
  /// "차단으로 사라진 부모"를 구분할 수 없어 고아 판정이 무너진다.
  Future<void> loadComments() async {
    final id = _postId;
    if (id == null || id.isEmpty) return;

    try {
      _isCommentsLoading.value = true;
      _commentsError.value = null;
      final rows = await _commentRepository.listComments(id);
      _comments.assignAll(rows);
    } catch (e) {
      log('CommunityPostDetailController.loadComments error: $e');
      _commentsError.value = communityErrorMessage(e);
    } finally {
      _isCommentsLoading.value = false;
    }
  }

  void onCommentChanged(String value) =>
      commentLength.value = value.trim().runes.length;

  /// 답글 모드 진입 — 입력바 상단에 대상이 표시되고 키보드가 올라온다.
  void startReply(CommunityCommentResponse comment) {
    if (!canReplyTo(comment)) return;
    _replyTarget.value = comment;
    commentFocusNode.requestFocus();
  }

  void cancelReply() => _replyTarget.value = null;

  /// 댓글/대댓글 등록.
  ///
  /// 순서가 중요하다. 작성 게이트([CommunityOnboardingController.ensureCanWrite])를
  /// **INSERT 전에** 통과시킨다 — 제출 시점에 걸리면 `cc_insert` 정책이 42501 을
  /// 던지는데, 그때는 원인이 "약관 미동의"인지 "정지"인지 알 수 없다.
  Future<void> submitComment() async {
    if (_isSubmittingComment.value) return;

    final postId = _postId;
    if (postId == null || postId.isEmpty) return;
    if (post == null) return;

    final firstError = _validateComment(commentInput.text.trim());
    if (firstError != null) {
      Get.snackbar('댓글 등록 실패', firstError, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // 게이트가 시트를 띄우는 동안에도 전송이 잠겨 있어야 한다. 그래서 플래그를
    // 게이트 *앞*에서 올린다 — 뒤에서 올리면 시트가 뜬 사이 두 번 제출될 수 있다.
    _isSubmittingComment.value = true;
    try {
      if (!await CommunityOnboardingController.ensureCanWrite()) return;

      // 게이트가 떠 있는 동안 입력이 바뀌었을 수 있어 다시 읽고 검증한다.
      final content = commentInput.text.trim();
      final error = _validateComment(content);
      if (error != null) {
        Get.snackbar('댓글 등록 실패', error, snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final target = _replyTarget.value;
      if (target != null && !canReplyTo(target)) {
        // 답글을 쓰는 사이 대상 댓글이 지워진 경우. 서버도 `parent_removed` 로
        // 막지만 여기서 되돌려 주는 편이 입력을 잃지 않는다.
        _replyTarget.value = null;
        Get.snackbar(
          '댓글 등록 실패',
          '삭제된 댓글에는 답글을 달 수 없습니다.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final created = await _commentRepository.createComment(
        CreateCommunityCommentParameter(
          postId: postId,
          parentId: target?.id,
          content: content,
        ),
      );
      _comments.add(created);
      commentInput.clear();
      commentLength.value = 0;
      _replyTarget.value = null;
      _bumpCommentCount(1);
    } catch (e) {
      log('CommunityPostDetailController.submitComment error: $e');
      Get.snackbar(
        '댓글 등록 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isSubmittingComment.value = false;
    }
  }

  /// 본인 댓글 삭제 확인 다이얼로그 → [deleteComment].
  Future<void> confirmDeleteComment(CommunityCommentResponse comment) async {
    final confirmed = await Get.dialog<bool>(
      _buildConfirmDialog(
        title: '댓글 삭제',
        message: '삭제한 댓글은 복구할 수 없습니다.\n삭제하시겠습니까?',
        confirmLabel: '삭제',
        danger: true,
      ),
    );
    if (confirmed == true) await deleteComment(comment);
  }

  /// 본인 댓글 삭제 (소프트 삭제 RPC).
  ///
  /// 낙관적으로 먼저 지우지 않는다. 삭제는 되돌릴 수 없는 조작이라 사라졌다
  /// 되살아나는 화면이 오히려 불안을 준다 — 서버 성공을 확인한 뒤 바꾼다.
  ///
  /// 성공하면 행은 남고 상태만 바뀌므로(대댓글 보존) 로컬에서도 같은 모양의
  /// 툼스톤으로 교체한다. 자식이 없으면 [threadedComments] 가 알아서 빼준다.
  Future<void> deleteComment(CommunityCommentResponse comment) async {
    final id = comment.id;
    if (id == null || id.isEmpty) return;
    if (!isMyComment(comment) || comment.isRemoved) return;
    if (_deletingCommentId.value != null) return;

    _deletingCommentId.value = id;
    try {
      await _commentRepository.deleteComment(id);

      final index = _comments.indexWhere((c) => c.id == id);
      if (index >= 0) _comments[index] = _comments[index].copyWithRemoved();
      if (_replyTarget.value?.id == id) _replyTarget.value = null;
      _bumpCommentCount(-1);
    } catch (e) {
      log('CommunityPostDetailController.deleteComment error: $e');
      Get.snackbar(
        '댓글 삭제 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _deletingCommentId.value = null;
    }
  }

  /// 게시글 댓글 수를 낙관적으로 조정하고 목록까지 전파한다.
  ///
  /// 실제 카운터는 `community_bump_comment_count` 트리거가 관리한다. 여기 값은
  /// 다음 서버 조회 전까지의 임시값이며, 서버 값이 오면 그쪽을 따른다.
  void _bumpCommentCount(int delta) {
    final current = post;
    if (current == null) return;
    final next = (current.commentCount ?? 0) + delta;
    final updated = current.copyWithCommentCount(next < 0 ? 0 : next);
    post = updated;
    _syncToList(updated);
  }

  // ── 신고 · 차단 · 운영자 조치 ────────────────────────────────────────────

  /// 운영자 여부 (`is_app_admin()`). 더보기 시트의 관리자 항목 노출 조건이다.
  ///
  /// 화면 진입 시 1회만 조회한다. 실패하면 false 로 남는데, 항목이 안 보이는
  /// 쪽이 안전한 실패 방향이고 어차피 모든 조치 RPC 가 서버에서 다시 검사한다.
  final _isAdmin = false.obs;
  bool get isAdmin => _isAdmin.value;

  /// 게시글이 숨김/삭제 상태인지. 운영자에게만 이 상태의 글이 보이며
  /// (`cp_select` 정책), 시트에서 "숨기기" 대신 "복구"를 그리는 기준이다.
  bool get isPostHidden {
    final status = post?.status;
    return status != null && status != 'visible';
  }

  Future<void> _loadAdminFlag() async {
    _isAdmin.value = await _moderationRepository.isAppAdmin();
  }

  /// 게시글 더보기(⋯) 시트.
  void showPostMoreSheet() {
    final current = post;
    final id = current?.id;
    if (current == null || id == null || id.isEmpty) return;

    final authorId = current.authorId;
    // 작성자를 알 수 없으면(탈퇴) 차단·정지 대상이 없다.
    final hasAuthor = authorId != null && authorId.isNotEmpty;
    final mine = isMine;

    CommunityMoreSheet.show(
      isMine: mine,
      isAdmin: isAdmin,
      isHidden: isPostHidden,
      onEdit: mine ? openEdit : null,
      onDelete: mine ? confirmDeletePost : null,
      onReport: mine ? null : () => _openReportSheet(targetPost: current),
      onBlock:
          (mine || !hasAuthor)
              ? null
              : () => confirmBlockUser(authorId, isPostAuthor: true),
      onSetHidden: () => _setPostStatus('hidden'),
      onSetVisible: () => _setPostStatus('visible'),
      onForceDelete:
          () => _confirmAdminAction(
            title: '강제 삭제',
            message: '이 게시글을 삭제 상태로 바꿉니다.\n작성자에게도 보이지 않게 됩니다.',
            confirmLabel: '삭제',
            danger: true,
            action: () => _setPostStatus('deleted'),
          ),
      onBanAuthor: hasAuthor ? () => _promptBanUser(authorId) : null,
      onResolveReports: () => _promptResolveReports(postId: id),
    );
  }

  /// 작성자 아바타·닉네임 탭 → 프로필 시트(보기 전용).
  ///
  /// [authorId] 가 null 이거나 비면 **탈퇴한 사용자**다(`author_id` 는
  /// `on delete set null`). 시트도 스낵바도 띄우지 않고 조용히 무시한다.
  ///
  /// [CommunityController.openProfile] 과 같은 구현을 각자 둔다 — 2곳뿐이고
  /// 꺼내 오는 모델이 서로 다르다(게시글 / 댓글).
  void openProfile(String? authorId, {String? nickname, String? avatarUrl}) {
    final id = authorId?.trim();
    if (id == null || id.isEmpty) return;
    CommunityProfileSheet.show(
      userId: id,
      fallbackNickname: nickname,
      fallbackAvatarUrl: avatarUrl,
    );
  }

  /// 댓글에 더보기(⋯)를 그릴지.
  ///
  /// 툼스톤(삭제·숨김)에는 일반 사용자가 할 수 있는 조치가 없다. 운영자만
  /// 숨김 댓글을 복구할 수 있으므로 그때만 진입점을 남긴다.
  bool canOpenCommentMoreSheet(CommunityCommentResponse comment) =>
      !comment.isRemoved || isAdmin;

  /// 댓글 더보기(⋯) 시트.
  void showCommentMoreSheet(CommunityCommentResponse comment) {
    final id = comment.id;
    if (id == null || id.isEmpty) return;
    // 툼스톤(삭제·숨김)에는 조치할 것이 없다 — 운영자의 복구만 예외다.
    if (comment.isRemoved && !isAdmin) return;

    final authorId = comment.authorId;
    final hasAuthor = authorId != null && authorId.isNotEmpty;
    final mine = isMyComment(comment);

    CommunityMoreSheet.show(
      isMine: mine,
      isAdmin: isAdmin,
      isHidden: comment.isRemoved,
      onDelete:
          (mine && !comment.isRemoved)
              ? () => confirmDeleteComment(comment)
              : null,
      onReport:
          (mine || comment.isRemoved)
              ? null
              : () => _openReportSheet(targetComment: comment),
      onBlock:
          (mine || !hasAuthor)
              ? null
              : () => confirmBlockUser(authorId, isPostAuthor: false),
      onSetHidden: () => _setCommentStatus(comment, 'hidden'),
      onSetVisible: () => _setCommentStatus(comment, 'visible'),
      onForceDelete:
          () => _confirmAdminAction(
            title: '강제 삭제',
            message: '이 댓글을 삭제 상태로 바꿉니다.\n작성자에게도 보이지 않게 됩니다.',
            confirmLabel: '삭제',
            danger: true,
            action: () => _setCommentStatus(comment, 'deleted'),
          ),
      onBanAuthor: hasAuthor ? () => _promptBanUser(authorId) : null,
      onResolveReports: () => _promptResolveReports(commentId: id),
    );
  }

  /// 신고 시트를 연다. [targetPost] 와 [targetComment] 중 하나만 넘긴다.
  ///
  /// 신고에는 작성 게이트([CommunityOnboardingController.ensureCanWrite])를
  /// 걸지 않는다. 서버도 `cr_insert_own` 에서 `community_can_write()` 를 보지
  /// 않는다 — 이용규칙에 동의하지 않았거나 정지된 사용자도 신고는 할 수 있어야
  /// 신고 창구가 막히지 않는다. 로그인만 요구한다.
  Future<void> _openReportSheet({
    CommunityPostResponse? targetPost,
    CommunityCommentResponse? targetComment,
  }) async {
    if (!_requireLogin()) return;

    final targetUserId = targetPost?.authorId ?? targetComment?.authorId;
    final isPostAuthor = targetPost != null;

    await CommunityReportSheet.show(
      targetLabel: targetPost != null ? '게시글' : '댓글',
      onSubmit: (reason, detail) async {
        final param =
            targetPost != null
                ? CreateCommunityReportParameter.post(
                  postId: targetPost.id ?? '',
                  reason: reason,
                  detail: detail,
                )
                : CreateCommunityReportParameter.comment(
                  commentId: targetComment?.id ?? '',
                  reason: reason,
                  detail: detail,
                );
        try {
          await _moderationRepository.createReport(param);
          // 사유에 따라 서버가 즉시 자동 숨김할 수 있다(음란물·불법 1건).
          // 화면을 서버 상태에 맞추기 위해 다시 읽는다.
          //
          // 댓글이 자동 숨김되면 트리거가 `comment_count` 도 내리므로
          // 게시글까지 조용히 다시 읽는다 — 낙관적 계산을 얹으면 트리거와
          // 이중으로 깎인다.
          unawaited(
            targetPost != null
                ? loadPost()
                : loadComments().then((_) => _refreshPostQuietly()),
          );
          return true;
        } catch (e) {
          log('CommunityPostDetailController.createReport error: $e');
          Get.snackbar(
            '신고 실패',
            communityErrorMessage(e),
            snackPosition: SnackPosition.BOTTOM,
          );
          return false;
        }
      },
      // 접수 완료 화면의 "이 사용자 차단하기". 이미 명시적으로 누른 CTA 라
      // 확인 다이얼로그를 한 번 더 띄우지 않는다.
      onBlock:
          (targetUserId == null || targetUserId.isEmpty)
              ? null
              : () => blockUser(targetUserId, isPostAuthor: isPostAuthor),
    );
  }

  /// 차단 확인 다이얼로그 → 차단.
  Future<void> confirmBlockUser(
    String userId, {
    required bool isPostAuthor,
  }) async {
    if (!_requireLogin()) return;

    final confirmed = await Get.dialog<bool>(
      _buildConfirmDialog(
        title: '사용자 차단',
        message: '이 사용자의 글과 댓글이 보이지 않게 됩니다.\n차단 사실은 상대에게 알려지지 않습니다.',
        confirmLabel: '차단',
        danger: true,
      ),
    );
    if (confirmed != true) return;
    await blockUser(userId, isPostAuthor: isPostAuthor);
  }

  /// 차단 실행.
  ///
  /// 목록에서 걸러내는 일은 클라이언트가 하지 않는다 — `community_is_blocked()`
  /// 를 참조하는 RLS 가 서버에서 양방향으로 처리하므로 다시 불러오기만 하면
  /// 된다.
  ///
  /// [isPostAuthor] 면 이 게시글 자체가 보이지 않게 되므로 상세를 닫고 목록을
  /// 새로 부른다. 댓글 작성자를 차단한 경우에는 글이 그대로 남아 있어, 상세에
  /// 머무른 채 댓글만 다시 읽는 편이 맥락을 잃지 않는다.
  Future<void> blockUser(String userId, {required bool isPostAuthor}) async {
    try {
      await _moderationRepository.blockUser(userId);
      if (isPostAuthor) {
        _removeFromList(post?.id ?? '');
        Get.back<void>();
        await _refreshList();
      } else {
        await loadComments();
        unawaited(_refreshList());
      }
      Get.snackbar(
        '차단 완료',
        '이 사용자의 글과 댓글이 보이지 않습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('CommunityPostDetailController.blockUser error: $e');
      Get.snackbar(
        '차단 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 운영자 — 게시글 상태 변경 (숨김 / 복구 / 강제 삭제).
  Future<void> _setPostStatus(String status) async {
    final id = post?.id;
    if (id == null || id.isEmpty) return;
    try {
      await _moderationRepository.setPostStatus(id, status);
      if (status == 'deleted') {
        _removeFromList(id);
        Get.back<void>();
        await _refreshList();
      } else {
        await loadPost();
      }
      Get.snackbar(
        '처리 완료',
        _statusMessage('게시글', status),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('CommunityPostDetailController._setPostStatus error: $e');
      Get.snackbar(
        '처리 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 운영자 — 댓글 상태 변경 (숨김 / 복구 / 강제 삭제).
  Future<void> _setCommentStatus(
    CommunityCommentResponse comment,
    String status,
  ) async {
    final id = comment.id;
    if (id == null || id.isEmpty) return;
    try {
      await _moderationRepository.setCommentStatus(id, status);
      await loadComments();
      // `visible ↔ 그 외` 전이에서 `community_bump_comment_count` 트리거가
      // 카운터를 움직인다. 본인 삭제 경로의 `_bumpCommentCount` 낙관적 감산을
      // 여기서 재사용하면 트리거와 이중으로 반영되므로, 계산하지 않고
      // 서버 값을 다시 읽는다.
      await _refreshPostQuietly();
      Get.snackbar(
        '처리 완료',
        _statusMessage('댓글', status),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('CommunityPostDetailController._setCommentStatus error: $e');
      Get.snackbar(
        '처리 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  static String _statusMessage(String kind, String status) {
    switch (status) {
      case 'hidden':
        return '$kind을 숨김 처리했습니다.';
      case 'visible':
        return '$kind을 복구했습니다.';
      default:
        return '$kind을 삭제했습니다.';
    }
  }

  /// 게시글을 **로딩 상태 없이** 다시 읽어 반영한다.
  ///
  /// [loadPost] 는 `isLoading` 을 올려 본문 자리를 스피너로 덮는다. 댓글 하나를
  /// 숨겼을 뿐인데 화면 전체가 깜빡이면 조작감이 나쁘므로, 카운터 동기화처럼
  /// 사용자가 기다리지 않는 갱신에는 이쪽을 쓴다.
  ///
  /// 조회 실패·0행은 조용히 무시한다 — 이 호출의 목적은 곁가지 값(카운터)을
  /// 맞추는 것이라, 실패를 알려 봐야 방금 성공한 조치가 실패한 것처럼 보인다.
  Future<void> _refreshPostQuietly() async {
    final id = _postId;
    if (id == null || id.isEmpty) return;
    try {
      final fetched = await _postRepository.fetchById(id);
      if (fetched == null) return;
      post = fetched;
      _syncToList(fetched);
    } catch (e) {
      log('CommunityPostDetailController._refreshPostQuietly error: $e');
    }
  }

  /// 운영자 — 작성자 이용 정지. 기간을 고르면 곧바로 실행한다.
  Future<void> _promptBanUser(String userId) async {
    final days = await Get.dialog<int>(
      AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          '작성자 정지',
          style: AppTypography.labelLg.copyWith(
            fontSize: 16.sp,
            color: Colors.white,
          ),
        ),
        content: Text(
          '정지 기간 동안 글과 댓글을 쓸 수 없습니다.\n(읽기는 그대로 가능합니다.)',
          style: AppTypography.bodyMd.copyWith(
            fontSize: 14.sp,
            color: AppColors.subtleText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<int>(),
            child: Text(
              '취소',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.subtleText,
              ),
            ),
          ),
          for (final option in const <int>[1, 7, 30])
            TextButton(
              onPressed: () => Get.back<int>(result: option),
              child: Text(
                '$option일',
                style: AppTypography.bodyMd.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.liveRed,
                ),
              ),
            ),
        ],
      ),
    );
    if (days == null) return;

    try {
      await _moderationRepository.banUser(userId, days);
      Get.snackbar(
        '정지 완료',
        '$days일간 커뮤니티 작성이 제한됩니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('CommunityPostDetailController._promptBanUser error: $e');
      Get.snackbar(
        '정지 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 운영자 — 이 콘텐츠에 달린 **미처리 신고 전체**를 한 번에 종결한다.
  ///
  /// 신고를 건건이 고르게 하지 않는다. 같은 콘텐츠에 쌓인 신고는 같은 판단을
  /// 받는 것이 정상이고, 폰에서 하나씩 처리하게 만들면 24시간 SLA 가 깨진다.
  Future<void> _promptResolveReports({
    String? postId,
    String? commentId,
  }) async {
    final List<String> ids;
    try {
      final reports = await _moderationRepository.listPendingReports(
        postId: postId,
        commentId: commentId,
      );
      ids =
          reports
              .map((r) => r.id)
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList();
    } catch (e) {
      log('CommunityPostDetailController._promptResolveReports error: $e');
      Get.snackbar(
        '신고 조회 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (ids.isEmpty) {
      Get.snackbar(
        '신고 종결',
        '미처리 신고가 없습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final status = await Get.dialog<String>(
      AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          '신고 종결',
          style: AppTypography.labelLg.copyWith(
            fontSize: 16.sp,
            color: Colors.white,
          ),
        ),
        content: Text(
          '미처리 신고 ${ids.length}건을 종결합니다.\n조치했다면 "조치함", 문제가 없다면 "기각"을 선택하세요.',
          style: AppTypography.bodyMd.copyWith(
            fontSize: 14.sp,
            color: AppColors.subtleText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<String>(),
            child: Text(
              '취소',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.subtleText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back<String>(result: 'rejected'),
            child: Text(
              '기각',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.subtleText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back<String>(result: 'actioned'),
            child: Text(
              '조치함',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
    if (status == null) return;

    try {
      for (final id in ids) {
        await _moderationRepository.resolveReport(id, status);
      }
      Get.snackbar(
        '신고 종결',
        '${ids.length}건을 처리했습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('CommunityPostDetailController.resolveReport error: $e');
      Get.snackbar(
        '신고 종결 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 되돌릴 수 없는 운영자 조치용 확인 다이얼로그.
  Future<void> _confirmAdminAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    bool danger = false,
  }) async {
    final confirmed = await Get.dialog<bool>(
      _buildConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        danger: danger,
      ),
    );
    if (confirmed == true) await action();
  }

  Widget _buildConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool danger,
  }) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text(
        title,
        style: AppTypography.labelLg.copyWith(
          fontSize: 16.sp,
          color: Colors.white,
        ),
      ),
      content: Text(
        message,
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
            confirmLabel,
            style: AppTypography.bodyMd.copyWith(
              fontSize: 14.sp,
              color: danger ? AppColors.liveRed : AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }

  /// 비로그인이면 로그인 화면으로 보낸다. 신고·차단의 공통 진입 조건이다.
  bool _requireLogin() {
    if (_currentUserId != null) return true;
    Get.toNamed<dynamic>(Routes.LOGIN);
    return false;
  }

  /// 목록 탭이 살아 있으면 새로 부른다. 차단·삭제의 결과는 서버 RLS 가
  /// 반영하므로 클라이언트는 다시 읽기만 한다.
  Future<void> _refreshList() async {
    if (!Get.isRegistered<CommunityController>()) return;
    await CommunityController.to.refreshPosts();
  }

  /// 제출 전 클라이언트 검증. 통과하면 null.
  String? _validateComment(String content) {
    if (content.isEmpty) return '댓글을 입력해주세요.';
    if (content.runes.length > CommunityCommentRepository.maxContentLength) {
      return '댓글은 ${CommunityCommentRepository.maxContentLength}자를 넘을 수 없습니다.';
    }
    final banned = CommunityTextFilter.findBannedWord(content, _bannedWords);
    if (banned != null) {
      return '사용할 수 없는 표현이 포함되어 있습니다.';
    }
    return null;
  }
}
