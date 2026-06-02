import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/get_live_matches_response.dart';
import '../models/live_match_response.dart';

/// 라이브 매치 관련 Supabase Edge Function 호출 레포지토리.
///
/// 모든 API 호출은 `Supabase.instance.client.functions.invoke(...)`를 경유한다.
/// Dio·http 패키지 또는 `from()` PostgREST 직접 접근을 사용하지 않는다.
///
/// 엔드포인트:
/// - `get-live-matches` : 현재 `tournament_status='live'`인 모든 매치
class LiveMatchRepository {
  /// Supabase client 접근자 (전역 client 사용)
  SupabaseClient get _client => Supabase.instance.client;

  /// 현재 라이브 중인 매치 목록 조회 — Edge Function: `get-live-matches`
  ///
  /// [tournamentId] (선택) 특정 대회로 필터.
  /// [eventName] (선택) 종목 필터 — `MS | WS | MD | WD | XD`.
  ///
  /// 라이브 매치가 0건이거나 미존재(404)인 경우 에러가 아니라
  /// "데이터 없음"으로 간주하여 빈 목록을 가진
  /// [GetLiveMatchesResponse]를 반환한다.
  /// 그 외 실패 시 `Exception('get-live-matches failed: ...')` 를 throw 한다.
  Future<GetLiveMatchesResponse> getLiveMatches({
    int? tournamentId,
    String? eventName,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (tournamentId != null) {
        query['tournament_id'] = '$tournamentId';
      }
      if (eventName != null && eventName.isNotEmpty) {
        query['event_name'] = eventName;
      }

      final res = await _client.functions.invoke(
        'get-live-matches',
        method: HttpMethod.get,
        queryParameters: query.isEmpty ? null : query,
      );

      // 데이터 없음: 빈 목록으로 정상 반환
      if (res.status == 404) {
        return GetLiveMatchesResponse(
          count: 0,
          matches: const <LiveMatchResponse>[],
        );
      }

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-live-matches failed: '
          'status=${res.status}, data=${res.data}',
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
          'get-live-matches failed: '
          'unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetLiveMatchesResponse.fromJson(json);
    } on FunctionException catch (e) {
      if (e.status == 404) {
        return GetLiveMatchesResponse(
          count: 0,
          matches: const <LiveMatchResponse>[],
        );
      }
      log(
        'LiveMatchRepository.getLiveMatches FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('LiveMatchRepository.getLiveMatches error: $e');
      rethrow;
    }
  }
}
