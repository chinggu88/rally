import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favorite_player_response.dart';

/// 좋아하는 선수(`favorite_players` 테이블)를 다루는 레포지토리.
///
/// 유저 스코프 데이터이므로 직접 `.from()` + RLS로 접근한다.
/// 선수 이름/국가/사진은 추가 시점 스냅샷으로 함께 저장한다.
class FavoritePlayerRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'favorite_players';

  /// 현재 사용자의 즐겨찾기 선수 목록 (최신 추가순).
  Future<List<FavoritePlayerResponse>> listFavorites() async {
    final user = _client.auth.currentUser;
    if (user == null) return const <FavoritePlayerResponse>[];

    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((e) => FavoritePlayerResponse.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } on PostgrestException catch (e) {
      log('FavoritePlayerRepository.listFavorites Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 특정 선수가 즐겨찾기 되어있는지 여부. 비로그인 시 false.
  Future<bool> isFavorite(int playerId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final row = await _client
        .from(_table)
        .select('player_id')
        .eq('user_id', user.id)
        .eq('player_id', playerId)
        .maybeSingle();
    return row != null;
  }

  /// 즐겨찾기 추가 (이미 있으면 무시).
  Future<void> addFavorite({
    required int playerId,
    String? playerName,
    String? countryCode,
    String? photoUrl,
  }) async {
    final user = _requireUser();
    try {
      await _client.from(_table).upsert(
        {
          'user_id': user.id,
          'player_id': playerId,
          'player_name': playerName,
          'country_code': countryCode,
          'photo_url': photoUrl,
        },
        onConflict: 'user_id,player_id',
      );
    } on PostgrestException catch (e) {
      log('FavoritePlayerRepository.addFavorite Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 즐겨찾기 삭제.
  Future<void> removeFavorite(int playerId) async {
    final user = _requireUser();
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', user.id)
          .eq('player_id', playerId);
    } on PostgrestException catch (e) {
      log('FavoritePlayerRepository.removeFavorite Postgrest: ${e.message}');
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
}
