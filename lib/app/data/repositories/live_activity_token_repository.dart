import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Activity push token(`live_activity_tokens`) 레포지토리.
///
/// 토큰은 **활동 단위**로 발급되고 수명 중에도 회전하므로, 서버가 APNs로
/// 스코어를 갱신하려면 최신 토큰을 계속 올려둬야 한다.
/// 유저 스코프 데이터라 직접 `.from()` + RLS로 접근한다.
class LiveActivityTokenRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'live_activity_tokens';

  /// 토큰 저장/갱신. 같은 (user, match_code)면 덮어쓴다.
  Future<void> saveToken({
    required String matchCode,
    required String pushToken,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from(_table).upsert(
        {
          'user_id': user.id,
          'match_code': matchCode,
          'push_token': pushToken,
        },
        onConflict: 'user_id,match_code',
      );
    } on PostgrestException catch (e) {
      log('LiveActivityTokenRepository.saveToken Postgrest: ${e.message}');
    }
  }

  /// Activity 종료 시 토큰 제거 — 서버가 죽은 토큰으로 푸시하지 않도록.
  Future<void> removeToken(String matchCode) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', user.id)
          .eq('match_code', matchCode);
    } on PostgrestException catch (e) {
      log('LiveActivityTokenRepository.removeToken Postgrest: ${e.message}');
    }
  }
}
