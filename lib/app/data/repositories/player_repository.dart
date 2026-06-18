import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/get_player_response.dart';
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
  /// [limit] 이번 페이지 건수 (서버 기본 30, 범위 1~100). null이면 서버 기본값.
  /// [offset] 건너뛸 행 수 (서버 기본 0, 범위 0~10000). null이면 서버 기본값.
  ///
  /// 실패 시 `Exception('get-players failed: ...')` 를 throw 한다.
  Future<GetPlayersResponse> getPlayers({
    String? category,
    int? limit,
    int? offset,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (category != null && category.isNotEmpty) {
        qp['category'] = category;
      }
      if (limit != null) qp['limit'] = '$limit';
      if (offset != null) qp['offset'] = '$offset';

      final res = await _client.functions.invoke(
        'get-players',
        method: HttpMethod.get,
        queryParameters: qp.isEmpty ? null : qp,
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

  /// 단일 선수 상세 조회 — Edge Function: `get-player`
  ///
  /// [id] `bwf_players.id` (양수). `get-players` 응답의 `player1_id`/`player2_id`.
  ///
  /// 미존재(404)는 에러가 아니라 "데이터 없음"으로 간주하여
  /// `player`가 null인 [GetPlayerResponse]를 반환한다.
  /// 그 외 실패 시 `Exception('get-player failed: ...')` 를 throw 한다.
  Future<GetPlayerResponse> getPlayer({required int id}) async {
    try {
      final res = await _client.functions.invoke(
        'get-player',
        method: HttpMethod.get,
        queryParameters: <String, dynamic>{'id': '$id'},
      );

      // 미존재: 빈 응답(player=null)으로 정상 반환
      if (res.status == 404) {
        return GetPlayerResponse(player: null);
      }

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-player failed: status=${res.status}, data=${res.data}',
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
          'get-player failed: unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetPlayerResponse.fromJson(json);
    } on FunctionException catch (e) {
      // Edge Function이 404를 예외로 던지는 환경 대응 — 미존재로 흡수
      if (e.status == 404) {
        return GetPlayerResponse(player: null);
      }
      log(
        'PlayerRepository.getPlayer FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('PlayerRepository.getPlayer error: $e');
      rethrow;
    }
  }
}
