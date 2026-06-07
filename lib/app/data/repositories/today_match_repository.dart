import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/get_today_matches_response.dart';
import '../models/today_match_response.dart';

/// 오늘 경기 관련 Supabase Edge Function 호출 레포지토리.
///
/// 모든 API 호출은 `Supabase.instance.client.functions.invoke(...)`를 경유한다.
/// Dio·http 패키지 또는 `from()` PostgREST 직접 접근을 사용하지 않는다.
///
/// 엔드포인트:
/// - `get-today-matches` : KST 기준 오늘 하루의 경기(결과/예정) 목록
class TodayMatchRepository {
  /// Supabase client 접근자 (전역 client 사용)
  SupabaseClient get _client => Supabase.instance.client;

  /// 오늘 경기 목록 조회 — Edge Function: `get-today-matches`
  ///
  /// [date] (선택, `YYYY-MM-DD`) — 기준 날짜를 지정. null이면 서버 기본값(KST 기준 오늘)을 사용.
  ///
  /// 결과가 0건이거나 미존재(404)인 경우 에러가 아니라
  /// "데이터 없음"으로 간주하여 빈 결과/예정 목록을 가진
  /// [GetTodayMatchesResponse]를 반환한다.
  /// 그 외 실패 시 `Exception('get-today-matches failed: ...')` 를 throw 한다.
  Future<GetTodayMatchesResponse> getTodayMatches({String? date}) async {
    try {
      final query = <String, dynamic>{};
      if (date != null && date.isNotEmpty) {
        query['date'] = date;
      }

      final res = await _client.functions.invoke(
        'get-today-matches',
        method: HttpMethod.get,
        queryParameters: query.isEmpty ? null : query,
      );

      // 데이터 없음: 빈 목록으로 정상 반환
      if (res.status == 404) {
        return GetTodayMatchesResponse(
          date: date,
          resultsCount: 0,
          upcomingCount: 0,
          results: const <TodayMatchResponse>[],
          upcoming: const <TodayMatchResponse>[],
        );
      }

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-today-matches failed: '
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
          'get-today-matches failed: '
          'unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetTodayMatchesResponse.fromJson(json);
    } on FunctionException catch (e) {
      if (e.status == 404) {
        return GetTodayMatchesResponse(
          date: date,
          resultsCount: 0,
          upcomingCount: 0,
          results: const <TodayMatchResponse>[],
          upcoming: const <TodayMatchResponse>[],
        );
      }
      log(
        'TodayMatchRepository.getTodayMatches FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('TodayMatchRepository.getTodayMatches error: $e');
      rethrow;
    }
  }
}
