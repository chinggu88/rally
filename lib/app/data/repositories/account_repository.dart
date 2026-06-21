import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

/// 회원탈퇴(계정 영구 삭제) 레포지토리.
///
/// 클라이언트는 auth 계정을 직접 삭제할 수 없으므로 service_role을 쓰는
/// Edge Function `delete-account`를 호출한 뒤 로컬 세션을 정리한다.
class AccountRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// 현재 로그인 사용자의 계정을 영구 삭제하고 로그아웃한다.
  ///
  /// 성공 시 profiles/favorite_players/device_tokens는 DB cascade로 함께 삭제된다.
  /// 실패 시 Exception을 throw 한다.
  Future<void> deleteAccount() async {
    try {
      final res = await _client.functions.invoke(
        'delete-account',
        method: HttpMethod.post,
      );

      if (res.status != 200) {
        final data = res.data;
        final msg = (data is Map && data['error'] is String)
            ? data['error'] as String
            : '회원탈퇴에 실패했습니다. (status=${res.status})';
        throw Exception(msg);
      }

      // 계정이 삭제됐으므로 로컬 세션 정리.
      await _client.auth.signOut();
    } on FunctionException catch (e) {
      log('AccountRepository.deleteAccount FunctionException: '
          'status=${e.status}, details=${e.details}');
      rethrow;
    } catch (e) {
      log('AccountRepository.deleteAccount error: $e');
      rethrow;
    }
  }
}
