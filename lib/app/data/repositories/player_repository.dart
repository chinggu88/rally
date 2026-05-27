import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/get_players_response.dart';

/// BWF 랭킹 선수 관련 Supabase Edge Function 호출 레포지토리.
///
/// 모든 API 호출은 `Supabase.instance.client.functions.invoke(...)`를 경유한다.
/// Dio·http 패키지 또는 `from()` PostgREST 직접 접근을 사용하지 않는다.
class PlayerRepository {
  /// Supabase client 접근자 (전역 client 사용)
  SupabaseClient get _client => Supabase.instance.client;

  /// 종목별 BWF 랭킹 선수 목록 조회 — Edge Function: `get-players`
  ///
  /// [category] 조회 종목 (`MS`, `WS`, `MD`, `WD`, `XD`).
  /// null이면 서버 기본값(`MS`)을 사용한다.
  ///
  /// 실패 시 `Exception('get-players failed: ...')` 를 throw 한다.
  Future<GetPlayersResponse> getPlayers({String? category}) async {
    try {
      final res = await _client.functions.invoke(
        'get-players',
        method: HttpMethod.get,
        queryParameters: category != null && category.isNotEmpty
            ? <String, dynamic>{'category': category}
            : null,
      );
      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-players failed: status=${res.status}, data=${res.data}',
        );
      }

      final raw = res.data;
      late final Map<String, dynamic> json;
      if (raw is Map<String, dynamic>) {
        json = raw;
      } else if (raw is Map) {
        json = Map<String, dynamic>.from(raw);
      } else {
        throw Exception(
          'get-players failed: unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetPlayersResponse.fromJson(json);
    } on FunctionException catch (e) {
      log(
        'PlayerRepository.getPlayers FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('PlayerRepository.getPlayers error: $e');
      rethrow;
    }
  }
}
