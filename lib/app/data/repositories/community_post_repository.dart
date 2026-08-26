import 'dart:developer';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/community_error.dart';
import '../models/community_post_response.dart';
import '../models/create_community_post_parameter.dart';
import '../models/update_community_post_parameter.dart';

/// 커뮤니티 게시글 레포지토리.
///
/// Edge Function을 경유하지 않고 `.from()` + RLS로 직접 접근한다
/// (`ChatMessageRepository` 패턴). 조회 대상은 테이블 `community_posts` 가
/// 아니라 뷰 `community_post_feed` 다 — 작성자 프로필과 `is_liked` 까지
/// 라운드트립 1회로 가져오기 위해서다.
///
/// 뷰는 `security_invoker = on` 이라 `community_posts` 의 RLS(공개 여부·차단)가
/// 그대로 적용된다. 다만 `cp_select` 정책은 **작성자 본인과 운영자** 행을
/// `status` 가 `visible` 이 아니어도 통과시키므로, 이들에게는 삭제·숨김 글까지
/// 내려온다. 그래서 목록 조회에서만 `deleted` 를 따로 제외한다([listPosts]).
/// `hidden` 은 거르지 않는다 — 작성자는 자기 글이 숨김된 사실을 알아야 하고
/// 운영자는 그 화면에서 복구 조치를 한다.
class CommunityPostRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// 목록/상세 조회용 피드 뷰 (`20260823000400_community_feed_views.sql`)
  static const String _feedView = 'community_post_feed';

  /// 좋아요 매핑 테이블. PK가 `(post_id, user_id)` 라 중복 INSERT는 23505로 막힌다.
  static const String _likesTable = 'community_post_likes';

  /// 쓰기 대상 테이블. 조회는 [_feedView] 지만 INSERT/UPDATE 는 테이블로 한다.
  static const String _postsTable = 'community_posts';

  /// 게시글 이미지 버킷 (`20260823000500_community_storage.sql`, public, 5MB).
  static const String _bucket = 'community';

  /// 버킷 `file_size_limit` 과 같은 값. 넘으면 업로드 전에 되돌린다.
  static const int maxImageBytes = 5 * 1024 * 1024;

  /// 게시글당 이미지 최대 장수 (`community_posts.image_paths` CHECK 와 동일).
  static const int maxImageCount = 5;

  /// 게시글 목록 조회 (created_at DESC, 커서 페이지네이션).
  ///
  /// [category] 가 null이면 "전체" — 카테고리 필터를 붙이지 않는다.
  /// [before] 가 주어지면 그 시각 *미만*의 게시글만 조회(다음 페이지 로드).
  ///
  /// 반환은 리스트 그대로다. Edge Function 응답 봉투가 없으므로 래퍼 모델을
  /// 두지 않고, `hasMore` 판단은 호출부에서 `length >= limit` 으로 처리한다.
  Future<List<CommunityPostResponse>> listPosts({
    String? category,
    DateTime? before,
    int limit = 20,
  }) async {
    try {
      // 본인·운영자 행은 RLS 를 그대로 통과하므로 삭제된 글을 여기서 거른다.
      var query = _client.from(_feedView).select().neq('status', 'deleted');
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map(
            (e) => CommunityPostResponse.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      log('CommunityPostRepository.listPosts Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 게시글 1건 조회 (상세 화면 진입 / 딥링크).
  ///
  /// 뷰가 `security_invoker = on` 이라 숨김·삭제·차단된 글은 애초에 0행으로
  /// 돌아온다. 그래서 `null` 은 "권한 없음"과 "존재하지 않음"을 구분하지 않으며,
  /// 호출부는 둘 다 동일한 에러 상태로 처리한다.
  Future<CommunityPostResponse?> fetchById(String id) async {
    try {
      final row =
          await _client.from(_feedView).select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return CommunityPostResponse.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      log('CommunityPostRepository.fetchById Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 좋아요 추가.
  ///
  /// `like_count` 는 트리거가 갱신한다 — 클라이언트에 카운터 컬럼 UPDATE 권한이
  /// 없으므로 직접 올리려 하면 42501 이다.
  ///
  /// 이미 좋아요한 글이면 PK 위반(23505)이 나는데, 이는 사용자 관점에서 목표
  /// 상태(좋아요됨)가 이미 달성된 것이므로 에러로 올리지 않고 조용히 성공 처리한다.
  Future<void> likePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      await _client.from(_likesTable).insert({
        'post_id': postId,
        'user_id': user.id,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // 이미 좋아요 상태 — 멱등 처리
        return;
      }
      log('CommunityPostRepository.likePost Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 좋아요 취소. 이미 취소된 상태여도 0행 삭제로 끝나므로 멱등하다.
  Future<void> unlikePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      await _client
          .from(_likesTable)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    } on PostgrestException catch (e) {
      log('CommunityPostRepository.unlikePost Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 조회수 증가 RPC. 갱신된 `view_count` 를 돌려준다.
  ///
  /// `view_count` 컬럼에 UPDATE 권한을 열지 않았으므로 `security definer` RPC로만
  /// 증가시킬 수 있다. 1인 1회 판정(`community_post_views`)도 서버가 하므로
  /// 클라이언트는 화면당 1회만 호출하면 되고 중복 방지 로직을 따로 둘 필요가 없다.
  /// 비로그인 사용자는 증가 없이 현재 값만 반환된다.
  Future<int?> incrementView(String postId) async {
    try {
      final result = await _client.rpc<dynamic>(
        'community_increment_view',
        params: <String, dynamic>{'p_post_id': postId},
      );
      if (result is int) return result;
      if (result is num) return result.toInt();
      if (result is String) return int.tryParse(result);
      return null;
    } on PostgrestException catch (e) {
      log('CommunityPostRepository.incrementView Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 로컬 이미지들을 `community` 버킷에 올리고 **상대 경로** 목록을 돌려준다.
  ///
  /// 경로 규칙은 `{uid}/{draftId}/{index}_{ts}.{ext}` 다. 첫 세그먼트가 uid 인
  /// 것이 핵심으로, 스토리지 RLS(`foldername(name)[1] = auth.uid()`)와
  /// `community_posts` INSERT 정책(모든 `image_paths` 원소가 `{uid}/` 로 시작)
  /// 두 곳이 동시에 이 규칙을 검사한다.
  ///
  /// **부분 실패 시 자기가 올린 것만 되돌린다.** 3장 중 2장을 올리고 3장째에서
  /// 실패하면 앞의 2장이 참조 없는 고아로 남으므로, 여기서 제거한 뒤 rethrow 한다.
  /// 호출부는 "성공하면 전부, 실패하면 하나도 없음"만 신경 쓰면 된다.
  Future<List<String>> uploadImages(String draftId, List<File> files) async {
    if (files.isEmpty) return const <String>[];
    final user = _requireUser();

    final uploaded = <String>[];
    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final length = await file.length();
        if (length > maxImageBytes) {
          throw const CommunityValidationException(
            '이미지 한 장의 크기는 5MB를 넘을 수 없습니다.',
          );
        }

        final ext = _extOf(file.path);
        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = '${user.id}/$draftId/${i}_$ts.$ext';

        await _client.storage
            .from(_bucket)
            .upload(
              path,
              file,
              fileOptions: FileOptions(
                upsert: false,
                contentType: _contentTypeOf(ext),
              ),
            );
        uploaded.add(path);
      }
      return uploaded;
    } catch (e) {
      log('CommunityPostRepository.uploadImages error: $e');
      // 이미 올라간 것만 되돌린다. 정리 실패는 삼킨다 — 원래 예외를 덮으면
      // 호출부가 진짜 원인을 잃는다.
      await removeImages(uploaded);
      rethrow;
    }
  }

  /// 스토리지에서 이미지들을 제거한다 (고아 정리 / 수정 시 교체분 삭제).
  ///
  /// **실패해도 던지지 않는다.** 이 호출은 항상 다른 작업의 뒷정리이고,
  /// 정리 실패로 본 작업의 성공/실패 판정을 뒤집으면 사용자에게 거짓말이 된다.
  /// 남은 파일은 참조되지 않을 뿐 화면에는 영향이 없다.
  Future<void> removeImages(List<String> paths) async {
    final targets = paths.where((p) => p.trim().isNotEmpty).toList();
    if (targets.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(targets);
    } catch (e) {
      log('CommunityPostRepository.removeImages error: $e');
    }
  }

  /// 게시글 작성. 생성된 행을 [CommunityPostResponse] 로 돌려준다.
  ///
  /// `author_id` 는 파라미터가 아니라 현재 세션에서 주입한다 — RLS 가
  /// `author_id = auth.uid()` 를 강제하므로 다른 값이 들어갈 여지를 두지 않는다.
  ///
  /// 반환 행은 테이블(`community_posts`) 행이라 뷰의 `author_nickname` /
  /// `is_liked` 가 없다. 화면에 그대로 쓰지 말고 목록/상세를 다시 조회한다.
  Future<CommunityPostResponse> createPost(
    CreateCommunityPostParameter parameter,
  ) async {
    final user = _requireUser();
    try {
      final row =
          await _client
              .from(_postsTable)
              .insert(<String, dynamic>{
                ...parameter.toJson(),
                'author_id': user.id,
              })
              .select()
              .single();
      return CommunityPostResponse.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      log('CommunityPostRepository.createPost Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 게시글 수정.
  ///
  /// 파라미터가 null 아닌 필드만 담기는 것이 필수다 — 클라이언트에는
  /// `(title, content, category, image_paths)` 컬럼 UPDATE 권한만 있어서
  /// 다른 컬럼이 섞이면 42501 로 전부 거부된다. `edited_at` 은 권한이 없으며
  /// `community_posts_edited_at` 트리거가 서버 시각으로 찍는다.
  Future<void> updatePost(
    String id,
    UpdateCommunityPostParameter parameter,
  ) async {
    final payload = parameter.toJson();
    if (payload.isEmpty) return;
    try {
      await _client.from(_postsTable).update(payload).eq('id', id);
    } on PostgrestException catch (e) {
      log('CommunityPostRepository.updatePost Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 게시글 소프트 삭제 RPC.
  ///
  /// 클라이언트에는 물리 DELETE 권한도 `status` 컬럼 UPDATE 권한도 없다
  /// (`20260823000200`). `.from().delete()` 나 `.update({'status': ...})` 는
  /// 42501 로 막히므로 반드시 이 RPC를 쓴다. 권한이 없으면 서버가
  /// `hint = 'forbidden'` 으로 예외를 던진다.
  Future<void> deletePost(String id) async {
    try {
      await _client.rpc<dynamic>(
        'community_delete_post',
        params: <String, dynamic>{'p_id': id},
      );
    } on PostgrestException catch (e) {
      log('CommunityPostRepository.deletePost Postgrest: ${e.message}');
      rethrow;
    }
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user;
  }

  /// `ProfileRepository.uploadAvatar` 와 동일한 확장자 추출.
  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    final ext = path.substring(dot + 1).toLowerCase();
    return ext.isEmpty ? 'jpg' : ext;
  }

  /// `ProfileRepository.uploadAvatar` 와 동일한 매핑.
  /// 버킷 `allowed_mime_types` 가 jpeg/png/webp/heic 만 받으므로 이외 확장자는
  /// jpeg 로 보내고, 실제로 형식이 다르면 스토리지가 415 로 거절한다.
  static String _contentTypeOf(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
