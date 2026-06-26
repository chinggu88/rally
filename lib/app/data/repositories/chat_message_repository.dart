import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message_response.dart';

/// 라이브 매치 채팅 메시지(`live_match_chat_messages`) 레포지토리.
///
/// 클라이언트가 `.from()` + RLS로 직접 접근(Edge Function 미경유). 메시지는
/// `profiles` 조인하여 작성자 닉네임/아바타와 함께 한 번에 가져온다.
class ChatMessageRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'live_match_chat_messages';
  static const String _profilesTable = 'profiles';

  /// 특정 매치의 메시지 목록 (created_at DESC).
  ///
  /// [before] 가 주어지면 그 시각 *미만*의 메시지만 조회(이전 페이지 로드).
  /// 클라이언트는 반환된 리스트를 reverse 해서 오름차순으로 표시.
  /// 작성자 닉네임/아바타는 profiles 별도 조회로 채워준다(FK 추론 의존 회피).
  Future<List<ChatMessageResponse>> listMessages({
    required int liveMatchId,
    DateTime? before,
    int limit = 50,
  }) async {
    try {
      var query = _client.from(_table).select().eq(
            'live_match_id',
            liveMatchId,
          );
      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = (rows as List)
          .map((e) => ChatMessageResponse.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
      return await _hydrateProfiles(messages);
    } on PostgrestException catch (e) {
      log('ChatMessageRepository.listMessages Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 단일 메시지 INSERT — 본인 user_id로 RLS 통과.
  /// 본인 user 정보로 작성자 필드를 채워 반환(profile 조회 불필요).
  Future<ChatMessageResponse> sendMessage({
    required int liveMatchId,
    required String content,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    try {
      final row = await _client
          .from(_table)
          .insert({
            'live_match_id': liveMatchId,
            'user_id': user.id,
            'content': content,
          })
          .select()
          .single();
      final msg = ChatMessageResponse.fromJson(Map<String, dynamic>.from(row));
      // 본인 프로필 1회 조회로 닉네임/아바타 첨부
      final hydrated = await _hydrateProfiles([msg]);
      return hydrated.first;
    } on PostgrestException catch (e) {
      log('ChatMessageRepository.sendMessage Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// id로 단일 메시지 조회 — Realtime INSERT 이벤트 후 작성자 프로필을 함께
  /// 가져오기 위해 사용.
  Future<ChatMessageResponse?> fetchById(String id) async {
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      final msg = ChatMessageResponse.fromJson(Map<String, dynamic>.from(row));
      final hydrated = await _hydrateProfiles([msg]);
      return hydrated.first;
    } on PostgrestException catch (e) {
      log('ChatMessageRepository.fetchById Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 본인 메시지 삭제 (RLS로 본인 행만 허용).
  Future<void> deleteMessage(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } on PostgrestException catch (e) {
      log('ChatMessageRepository.deleteMessage Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 메시지 리스트의 user_id로 profiles 일괄 조회 후 닉네임/아바타 첨부.
  Future<List<ChatMessageResponse>> _hydrateProfiles(
    List<ChatMessageResponse> messages,
  ) async {
    if (messages.isEmpty) return messages;
    final userIds = messages.map((m) => m.userId).toSet().toList();
    try {
      final profiles = await _client
          .from(_profilesTable)
          .select('id, nickname, avatar_url')
          .inFilter('id', userIds);
      final byId = <String, Map<String, dynamic>>{};
      for (final p in (profiles as List)) {
        final map = Map<String, dynamic>.from(p as Map);
        final pid = map['id'] as String?;
        if (pid != null) byId[pid] = map;
      }
      return messages
          .map((m) {
            final p = byId[m.userId];
            if (p == null) return m;
            return m.copyWithAuthor(
              nickname: p['nickname'] as String?,
              avatarUrl: p['avatar_url'] as String?,
            );
          })
          .toList();
    } on PostgrestException catch (e) {
      log('ChatMessageRepository._hydrateProfiles Postgrest: ${e.message}');
      // 프로필 조회 실패는 치명적이지 않음 — 닉네임 없이 반환
      return messages;
    }
  }
}
