import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_response.dart';

/// 알림(`notifications` 테이블) 레포지토리.
///
/// 발송 결과(status='sent'|'failed')와 무관하게 본인의 모든 알림을 조회한다.
/// 유저 스코프 데이터이므로 RLS로 본인 행만 노출.
class NotificationRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'notifications';

  /// 현재 사용자의 알림 목록 (최신순).
  Future<List<NotificationResponse>> listNotifications({int limit = 100}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const <NotificationResponse>[];

    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .order('sent_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((e) => NotificationResponse.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } on PostgrestException catch (e) {
      log('NotificationRepository.listNotifications Postgrest: ${e.message}');
      rethrow;
    }
  }
}
