import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM 디바이스 토큰을 Supabase `device_tokens` 테이블에 동기화한다.
///
/// 한 사용자가 여러 디바이스(iPhone + Android 등)를 가질 수 있어
/// (user_id, fcm_token) 기준으로 upsert 한다. fcm_token 자체가 UNIQUE.
class DeviceTokenRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'device_tokens';

  /// 현재 로그인 사용자의 FCM 토큰을 저장.
  ///
  /// `claim_device_token` RPC(SECURITY DEFINER)를 호출한다. FCM 토큰은 물리
  /// 기기 1대를 식별하므로, 같은 토큰이 다른 계정 소유로 남아있으면(계정 전환)
  /// 서버가 소유권을 현재 유저로 이관한 뒤 upsert한다. 직접 INSERT/UPDATE는
  /// RLS 때문에 타 유저 행을 정리할 수 없어 23505로 스킵되는 문제가 있었다.
  ///
  /// - 비로그인 상태에서는 저장하지 않는다.
  /// - currentUser가 DB에서 이미 삭제된 stale 세션이면(FK 위반) 강제 signOut으로
  ///   복구해 다음 부팅 때 정상 로그인 흐름을 타도록 한다.
  Future<void> upsertToken({
    required String fcmToken,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      log('DeviceTokenRepository.upsertToken: skipped (not logged in)');
      return;
    }

    try {
      await _client.rpc(
        'claim_device_token',
        params: {
          'p_fcm_token': fcmToken,
          'p_platform': platform,
          'p_device_name': deviceName,
          'p_app_version': appVersion,
        },
      );
      log('DeviceTokenRepository.upsertToken: ok (${fcmToken.substring(0, 12)}...)');
    } on PostgrestException catch (e) {
      // FK 위반(23503): 캐시된 세션의 user_id가 auth.users에 없음 → 유령 세션.
      // 강제 로그아웃해서 다음 부팅 때 깨끗한 로그인 흐름을 타도록 한다.
      if (e.code == '23503') {
        log(
          'DeviceTokenRepository.upsertToken: stale session detected '
          '(user_id=${user.id} not in auth.users) — forcing signOut',
        );
        await _client.auth.signOut();
        return;
      }
      log('DeviceTokenRepository.upsertToken Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 현재 디바이스의 FCM 토큰을 삭제 (로그아웃 시 호출).
  ///
  /// RLS 정책상 본인의 토큰만 삭제 가능.
  Future<void> deleteToken(String fcmToken) async {
    try {
      await _client.from(_table).delete().eq('fcm_token', fcmToken);
      log('DeviceTokenRepository.deleteToken: ok (${fcmToken.substring(0, 12)}...)');
    } on PostgrestException catch (e) {
      log('DeviceTokenRepository.deleteToken Postgrest: ${e.message}');
      // 로그아웃 흐름을 막지 않도록 rethrow 하지 않음.
    }
  }
}
