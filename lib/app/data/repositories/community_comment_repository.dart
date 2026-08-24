import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_comment_response.dart';
import '../models/create_community_comment_parameter.dart';

/// 커뮤니티 댓글 레포지토리.
///
/// [CommunityPostRepository] 와 같은 구조다 — Edge Function 을 경유하지 않고
/// `.from()` + RLS 로 직접 접근하며, **조회 대상은 테이블이 아니라 뷰**
/// `community_comment_feed` 다. 뷰는 작성자 프로필을 조인해 주고 삭제·숨김
/// 댓글의 본문/작성자를 NULL 로 마스킹한다(`20260823000400`).
///
/// 쓰기 경로에 세 가지 서버 제약이 걸려 있다. 어기면 42501 이라 반드시 지킨다:
///   · 삭제는 `community_delete_comment` RPC 로만 한다. `.from().delete()` 도
///     `.update({'status': ...})` 도 권한이 없다(`20260823000200` 컬럼 GRANT).
///   · UPDATE 가능 컬럼은 `content` **하나뿐**이다. `edited_at` 은 보내지 않으며
///     `community_comments_edited_at` 트리거가 서버 시각으로 찍는다.
///   · INSERT 의 `author_id` 는 세션에서 주입한다.
class CommunityCommentRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// 목록 조회용 피드 뷰 (`20260823000400_community_feed_views.sql`)
  static const String _feedView = 'community_comment_feed';

  /// 쓰기 대상 테이블. 조회는 [_feedView] 지만 INSERT/UPDATE 는 테이블로 한다.
  static const String _commentsTable = 'community_comments';

  /// 본문 길이 상한 — 테이블 CHECK(`1~1000`) 와 같은 값.
  static const int maxContentLength = 1000;

  /// 게시글의 댓글 전체 조회 (created_at ASC).
  ///
  /// 페이지네이션을 두지 않는다. 서버가 1depth 로 제한하는 스레드 구조라
  /// 부분 로딩을 하면 부모 없는 대댓글 조각을 받게 되고, 그러면 클라이언트가
  /// "고아"와 "아직 안 받은 부모"를 구분할 수 없다.
  ///
  /// 삭제·숨김 댓글도 스레드 유지를 위해 행이 내려올 수 있다. 본문은 NULL 이며
  /// 툼스톤 판정은 [CommunityCommentResponse.isRemoved] 가 한다.
  Future<List<CommunityCommentResponse>> listComments(String postId) async {
    try {
      final rows = await _client
          .from(_feedView)
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (rows as List)
          .map(
            (e) => CommunityCommentResponse.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      log('CommunityCommentRepository.listComments Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 댓글/대댓글 작성. 생성된 행을 **뷰에서 다시 읽어** 돌려준다.
  ///
  /// INSERT 의 `.select()` 는 테이블 행이라 `author_nickname` 이 없다.
  /// 그대로 화면에 넣으면 방금 쓴 내 댓글만 작성자가 비어 보이므로,
  /// id 로 피드 뷰를 한 번 더 읽어 프로필이 채워진 행을 반환한다.
  /// (전체 목록 재조회는 스크롤 위치가 튀므로 쓰지 않는다.)
  ///
  /// 서버 트리거가 거부하는 경우는 그대로 [PostgrestException] 으로 올라간다.
  /// 호출부가 `communityErrorMessage()` 로 한국어 변환한다:
  ///   · `depth_exceeded`  대댓글에 답글
  ///   · `parent_removed`  삭제된 댓글에 답글
  ///   · `banned_word`     금칙어
  ///   · `42501`           약관 미동의 / 이용 정지 / 삭제된 부모 글
  Future<CommunityCommentResponse> createComment(
    CreateCommunityCommentParameter parameter,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    try {
      final inserted =
          await _client
              .from(_commentsTable)
              .insert(<String, dynamic>{
                ...parameter.toJson(),
                'author_id': user.id,
              })
              .select('id')
              .single();

      final id = inserted['id'] as String?;
      if (id != null && id.isNotEmpty) {
        final hydrated = await fetchById(id);
        if (hydrated != null) return hydrated;
      }

      // 뷰 재조회가 비었을 때의 방어. 작성 자체는 성공했으므로 실패로 만들지
      // 않고, 프로필만 비어 있는 최소 행을 돌려준다.
      return CommunityCommentResponse(
        id: id,
        postId: parameter.postId,
        parentId: parameter.parentId,
        authorId: user.id,
        content: parameter.content,
        replyCount: 0,
        status: 'visible',
        createdAt: DateTime.now(),
      );
    } on PostgrestException catch (e) {
      log('CommunityCommentRepository.createComment Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 댓글 1건 조회 (작성 직후 프로필 hydrate 용).
  Future<CommunityCommentResponse?> fetchById(String id) async {
    try {
      final row =
          await _client.from(_feedView).select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return CommunityCommentResponse.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      log('CommunityCommentRepository.fetchById Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 댓글 본문 수정.
  ///
  /// **`content` 외의 컬럼을 절대 함께 보내지 않는다.** 클라이언트에는
  /// `grant update (content)` 만 있어(`20260823000200`) 다른 컬럼이 한 개라도
  /// 섞이면 요청 전체가 42501 로 거부된다. `edited_at` 은 권한이 없으며
  /// `community_comments_edited_at` 트리거가 서버 시각으로 찍는다.
  Future<void> updateComment(String id, String content) async {
    try {
      await _client
          .from(_commentsTable)
          .update(<String, dynamic>{'content': content})
          .eq('id', id);
    } on PostgrestException catch (e) {
      log('CommunityCommentRepository.updateComment Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 댓글 소프트 삭제 RPC.
  ///
  /// 물리 DELETE 권한도 `status` 컬럼 UPDATE 권한도 없다. 이 RPC 만이 경로이며,
  /// 권한이 없으면 서버가 `hint = 'forbidden'` 으로 예외를 던진다.
  /// 행은 남고 상태만 `deleted` 가 되므로 대댓글은 고아가 되지 않는다.
  Future<void> deleteComment(String id) async {
    try {
      await _client.rpc<dynamic>(
        'community_delete_comment',
        params: <String, dynamic>{'p_id': id},
      );
    } on PostgrestException catch (e) {
      log('CommunityCommentRepository.deleteComment Postgrest: ${e.message}');
      rethrow;
    }
  }
}
