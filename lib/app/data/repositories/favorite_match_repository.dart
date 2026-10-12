import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/favorite_match_response.dart';

/// 관심 경기(`favorite_matches` 테이블)를 다루는 레포지토리.
///
/// 유저 스코프 데이터이므로 직접 `.from()` + RLS로 접근한다.
/// 대회명/선수명/스코어는 위젯 렌더용 스냅샷으로 함께 저장한다.
///
/// 논리 키는 `match_code`다 — `bwf_matches.id`와 `bwf_live_matches.id`는
/// 서로 다른 테이블의 PK라 라이브 전환 시 이어지지 않는다.
class FavoriteMatchRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'favorite_matches';

  /// 현재 사용자의 관심 경기 목록 (최근 갱신순).
  Future<List<FavoriteMatchResponse>> listFavorites() async {
    final user = _client.auth.currentUser;
    if (user == null) return const <FavoriteMatchResponse>[];

    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false);

      return (rows as List)
          .map((e) => FavoriteMatchResponse.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } on PostgrestException catch (e) {
      log('FavoriteMatchRepository.listFavorites Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 특정 경기가 관심 등록되어 있는지 여부. 비로그인 시 false.
  Future<bool> isFavorite(String matchCode) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final row = await _client
        .from(_table)
        .select('match_code')
        .eq('user_id', user.id)
        .eq('match_code', matchCode)
        .maybeSingle();
    return row != null;
  }

  /// 관심 경기 추가 (이미 있으면 스냅샷 갱신).
  Future<void> addFavorite({
    required String matchCode,
    int? matchId,
    String? tournamentName,
    String? roundName,
    String? eventName,
    String? courtName,
    String? team1Name,
    String? team1Country,
    String? team2Name,
    String? team2Country,
    String? score,
    String? matchStatus,
    String? matchTimeKst,
    bool isLive = false,
  }) async {
    final user = _requireUser();
    try {
      await _client.from(_table).upsert(
        {
          'user_id': user.id,
          'match_code': matchCode,
          'match_id': matchId,
          'tournament_name': tournamentName,
          'round_name': roundName,
          'event_name': eventName,
          'court_name': courtName,
          'team1_name': team1Name,
          'team1_country': team1Country,
          'team2_name': team2Name,
          'team2_country': team2Country,
          'score': score,
          'match_status': matchStatus,
          'match_time_kst': matchTimeKst,
          'is_live': isLive,
        },
        onConflict: 'user_id,match_code',
      );
    } on PostgrestException catch (e) {
      log('FavoriteMatchRepository.addFavorite Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 관심 경기 삭제.
  Future<void> removeFavorite(String matchCode) async {
    final user = _requireUser();
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', user.id)
          .eq('match_code', matchCode);
    } on PostgrestException catch (e) {
      log('FavoriteMatchRepository.removeFavorite Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 스코어 스냅샷만 갱신한다 (Realtime/새로고침 반영용).
  Future<void> updateSnapshot({
    required String matchCode,
    String? score,
    String? matchStatus,
    bool? isLive,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final patch = <String, dynamic>{
      if (score != null) 'score': score,
      if (matchStatus != null) 'match_status': matchStatus,
      if (isLive != null) 'is_live': isLive,
    };
    if (patch.isEmpty) return;

    try {
      await _client
          .from(_table)
          .update(patch)
          .eq('user_id', user.id)
          .eq('match_code', matchCode);
    } on PostgrestException catch (e) {
      log('FavoriteMatchRepository.updateSnapshot Postgrest: ${e.message}');
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
