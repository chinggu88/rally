import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/get_tournaments_response.dart';

/// BWF 국제 대회 관련 Supabase Edge Function 호출 레포지토리.
///
/// 모든 API 호출은 `Supabase.instance.client.functions.invoke(...)`를 경유한다.
/// Dio·http 패키지 또는 `from()` PostgREST 직접 접근을 사용하지 않는다.
class TournamentRepository {
  /// Supabase client 접근자 (전역 client 사용)
  SupabaseClient get _client => Supabase.instance.client;

  /// 연도별 대회 목록 조회 — Edge Function: `get-tournaments`
  ///
  /// [year] 조회 연도 (예: `2026`). null이면 서버 기본값(현재 연도)을 사용한다.
  /// 유효 범위는 2000–2100.
  ///
  /// 실패 시 `Exception('get-tournaments failed: ...')` 를 throw 한다.
  Future<GetTournamentsResponse> getTournaments({int? year}) async {
    try {
      final res = await _client.functions.invoke(
        'get-tournaments',
        method: HttpMethod.get,
        queryParameters: year != null
            ? <String, dynamic>{'year': year.toString()}
            : null,
      );
      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-tournaments failed: status=${res.status}, data=${res.data}',
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
          'get-tournaments failed: unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetTournamentsResponse.fromJson(json);
    } on FunctionException catch (e) {
      log(
        'TournamentRepository.getTournaments FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('TournamentRepository.getTournaments error: $e');
      rethrow;
    }
  }
}
