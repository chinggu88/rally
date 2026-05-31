import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/get_tournament_matches_response.dart';
import '../models/get_tournament_participants_response.dart';
import '../models/get_tournament_response.dart';
import '../models/get_tournaments_response.dart';
import '../models/tournament_match_response.dart';
import '../models/tournament_participant_response.dart';

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

  /// 단일 대회 상세 조회 — Edge Function: `get-tournament`
  ///
  /// [tournamentId] `bwf_tournaments.tournament_id` (BWF tournament id, 양수).
  /// `get-tournaments` 응답의 각 항목 `tournament_id` 값을 그대로 전달한다.
  ///
  /// 미존재(404)는 에러가 아니라 "데이터 없음"으로 간주하여
  /// `tournament`가 null인 [GetTournamentResponse]를 반환한다.
  /// 그 외 실패 시 `Exception('get-tournament failed: ...')` 를 throw 한다.
  Future<GetTournamentResponse> getTournament({
    required int tournamentId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'get-tournament',
        method: HttpMethod.get,
        queryParameters: <String, dynamic>{'tournament_id': '$tournamentId'},
      );

      // 미존재: 빈 응답(tournament=null)으로 정상 반환
      if (res.status == 404) {
        return GetTournamentResponse(tournament: null);
      }

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-tournament failed: status=${res.status}, data=${res.data}',
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
          'get-tournament failed: unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetTournamentResponse.fromJson(json);
    } on FunctionException catch (e) {
      // Edge Function이 404를 예외로 던지는 환경 대응 — 미존재로 흡수
      if (e.status == 404) {
        return GetTournamentResponse(tournament: null);
      }
      log(
        'TournamentRepository.getTournament FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('TournamentRepository.getTournament error: $e');
      rethrow;
    }
  }

  /// 대회 경기(매치) 목록 조회 — Edge Function: `get-tournament-matches`
  ///
  /// [tournamentId] `bwf_matches.tournament_id` (BWF tournament id, 양수).
  ///
  /// 경기가 없으면 빈 목록을 가진 [GetTournamentMatchesResponse]를 반환한다.
  /// 실패 시 `Exception('get-tournament-matches failed: ...')` 를 throw 한다.
  Future<GetTournamentMatchesResponse> getTournamentMatches({
    required int tournamentId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'get-tournament-matches',
        method: HttpMethod.get,
        queryParameters: <String, dynamic>{'tournament_id': '$tournamentId'},
      );

      // 데이터 없음: 빈 목록으로 정상 반환
      if (res.status == 404) {
        return GetTournamentMatchesResponse(
          tournamentId: tournamentId,
          count: 0,
          matches: const <TournamentMatchResponse>[],
        );
      }

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-tournament-matches failed: '
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
          'get-tournament-matches failed: '
          'unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetTournamentMatchesResponse.fromJson(json);
    } on FunctionException catch (e) {
      if (e.status == 404) {
        return GetTournamentMatchesResponse(
          tournamentId: tournamentId,
          count: 0,
          matches: const <TournamentMatchResponse>[],
        );
      }
      log(
        'TournamentRepository.getTournamentMatches FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('TournamentRepository.getTournamentMatches error: $e');
      rethrow;
    }
  }

  /// 대회 참가 선수 목록 조회 — Edge Function: `get-tournament-participants`
  ///
  /// [tournamentId] `bwf_tournaments.tournament_id` (BWF tournament id, 양수).
  /// [eventName] 종목 코드 — `MS | WS | MD | WD | XD`.
  ///
  /// 참가자가 없거나 미존재(404)는 에러가 아니라 "데이터 없음"으로 간주해
  /// 빈 목록을 가진 [GetTournamentParticipantsResponse]를 반환한다.
  /// 그 외 실패 시 `Exception('get-tournament-participants failed: ...')` throw.
  Future<GetTournamentParticipantsResponse> getTournamentParticipants({
    required int tournamentId,
    required String eventName,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'get-tournament-participants',
        method: HttpMethod.get,
        queryParameters: <String, dynamic>{
          'tournament_id': '$tournamentId',
          'event_name': eventName,
        },
      );

      // 데이터 없음: 빈 목록으로 정상 반환
      if (res.status == 404) {
        return GetTournamentParticipantsResponse(
          tournamentId: tournamentId,
          eventName: eventName,
          count: 0,
          participants: const <TournamentParticipantResponse>[],
        );
      }

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-tournament-participants failed: '
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
          'get-tournament-participants failed: '
          'unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetTournamentParticipantsResponse.fromJson(json);
    } on FunctionException catch (e) {
      if (e.status == 404) {
        return GetTournamentParticipantsResponse(
          tournamentId: tournamentId,
          eventName: eventName,
          count: 0,
          participants: const <TournamentParticipantResponse>[],
        );
      }
      log(
        'TournamentRepository.getTournamentParticipants FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('TournamentRepository.getTournamentParticipants error: $e');
      rethrow;
    }
  }
}
