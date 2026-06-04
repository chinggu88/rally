import 'news_card_response.dart';

/// Edge Function `get-news-cards` 의 최상위 응답 래퍼.
///
/// `card_created = true` 인 기사(카드뉴스 생성 완료)만 페이지 단위로 내려준다.
///
/// 응답 예시:
/// ```json
/// {
///   "page": 1,
///   "per_page": 20,
///   "count": 1,
///   "total": 1,
///   "cards": [ { "id": 1, "card_storage_paths": { ... } } ]
/// }
/// ```
class GetNewsCardsResponse {
  /// 현재 페이지 번호(1부터)
  int? _page;

  /// 페이지당 개수
  int? _perPage;

  /// 이번 페이지 행 수
  int? _count;

  /// card_created=true 전체 건수
  int? _total;

  /// 카드뉴스 목록 (최신순)
  List<NewsCardResponse>? _cards;

  GetNewsCardsResponse({
    int? page,
    int? perPage,
    int? count,
    int? total,
    List<NewsCardResponse>? cards,
  }) {
    _page = page;
    _perPage = perPage;
    _count = count;
    _total = total;
    _cards = cards;
  }

  int? get page => _page;
  int? get perPage => _perPage;
  int? get count => _count;
  int? get total => _total;
  List<NewsCardResponse> get cards => _cards ?? const <NewsCardResponse>[];

  GetNewsCardsResponse.fromJson(Map<String, dynamic> json) {
    _page = _asInt(json['page']);
    _perPage = _asInt(json['per_page']);
    _count = _asInt(json['count']);
    _total = _asInt(json['total']);

    final list = json['cards'];
    if (list is List) {
      _cards = list
          .whereType<Map<String, dynamic>>()
          .map((item) => NewsCardResponse.fromJson(item))
          .toList();
    } else {
      _cards = null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'page': _page,
      'per_page': _perPage,
      'count': _count,
      'total': _total,
      'cards': _cards?.map((item) => item.toJson()).toList(),
    };
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
