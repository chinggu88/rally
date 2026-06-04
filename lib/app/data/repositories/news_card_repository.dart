import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/get_news_cards_response.dart';
import '../models/news_card_response.dart';

/// 카드뉴스 관련 Supabase Edge Function 호출 레포지토리.
///
/// 모든 API 호출은 `Supabase.instance.client.functions.invoke(...)`를 경유한다.
/// Dio·http 패키지 또는 `from()` PostgREST 직접 접근을 사용하지 않는다.
///
/// 엔드포인트:
/// - `get-news-cards` : `card_created=true` 인 기사의 `card_storage_paths` 목록
class NewsCardRepository {
  /// Supabase client 접근자 (전역 client 사용)
  SupabaseClient get _client => Supabase.instance.client;

  /// 카드뉴스 목록 조회 — Edge Function: `get-news-cards`
  ///
  /// [page] 1부터 시작하는 페이지 번호(기본 1).
  /// [perPage] 페이지당 개수(기본 20).
  ///
  /// 데이터가 0건이거나 미존재(404)인 경우 에러가 아니라 "데이터 없음"으로
  /// 간주하여 빈 목록을 가진 [GetNewsCardsResponse]를 반환한다.
  /// 그 외 실패 시 `Exception('get-news-cards failed: ...')` 를 throw 한다.
  Future<GetNewsCardsResponse> getNewsCards({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'get-news-cards',
        method: HttpMethod.get,
        queryParameters: <String, dynamic>{
          'page': '$page',
          'per_page': '$perPage',
        },
      );

      // 데이터 없음: 빈 목록으로 정상 반환
      if (res.status == 404) {
        return GetNewsCardsResponse(
          page: page,
          perPage: perPage,
          count: 0,
          total: 0,
          cards: const <NewsCardResponse>[],
        );
      }

      if (res.status != 200 || res.data == null) {
        throw Exception(
          'get-news-cards failed: '
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
          'get-news-cards failed: '
          'unexpected payload type ${raw.runtimeType}',
        );
      }

      return GetNewsCardsResponse.fromJson(json);
    } on FunctionException catch (e) {
      if (e.status == 404) {
        return GetNewsCardsResponse(
          page: page,
          perPage: perPage,
          count: 0,
          total: 0,
          cards: const <NewsCardResponse>[],
        );
      }
      log(
        'NewsCardRepository.getNewsCards FunctionException: '
        'status=${e.status}, details=${e.details}',
      );
      rethrow;
    } catch (e) {
      log('NewsCardRepository.getNewsCards error: $e');
      rethrow;
    }
  }
}
