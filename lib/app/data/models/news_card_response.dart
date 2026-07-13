/// 카드뉴스 1건 — Edge Function `get-news-cards` 의 `cards[]` 요소.
///
/// 원본 컬럼 `badminton_planet_news.card_storage_paths` 는 JSONB 객체이며,
/// 카드 이미지 배열(`cards`)과 버킷/폴더/미리보기 메타를 함께 담는다.
///
/// 행에는 `source`(뉴스 출처, 예: "badmintonplanet.com")도 함께 내려온다.
///
/// 응답 예시(card_storage_paths):
/// ```json
/// {
///   "cards": [
///     { "path": "...", "index": 1, "public_url": "https://.../card-01.png" },
///     { "path": "...", "index": 2, "public_url": "https://.../card-02.png" }
///   ],
///   "bucket": "badminton-planet-news",
///   "folder": "badminton_planet_news/id-1/...",
///   "preview": { "path": "...", "public_url": "https://.../index.html" },
///   "generated_at": "2026-06-04T01:31:04.419Z"
/// }
/// ```
class NewsCardResponse {
  /// badminton_planet_news.id (기사 식별자)
  int? _id;

  /// 뉴스 출처 slug (badminton_planet_news.source, 예: badmintonplanet.com)
  String? _source;

  /// Storage 버킷명 (예: badminton-planet-news)
  String? _bucket;

  /// 기사별 폴더 경로
  String? _folder;

  /// 카드 이미지 목록 (index ASC 정렬)
  List<NewsCardImage>? _cards;

  /// 미리보기(index.html) 공개 URL
  String? _previewUrl;

  /// 카드 생성 시각(ISO8601 문자열)
  String? _generatedAt;

  NewsCardResponse({
    int? id,
    String? source,
    String? bucket,
    String? folder,
    List<NewsCardImage>? cards,
    String? previewUrl,
    String? generatedAt,
  }) {
    _id = id;
    _source = source;
    _bucket = bucket;
    _folder = folder;
    _cards = cards;
    _previewUrl = previewUrl;
    _generatedAt = generatedAt;
  }

  int? get id => _id;
  String? get source => _source;
  String? get bucket => _bucket;
  String? get folder => _folder;
  List<NewsCardImage> get cards => _cards ?? const <NewsCardImage>[];
  String? get previewUrl => _previewUrl;
  String? get generatedAt => _generatedAt;

  /// 표지로 쓸 첫 카드(card-01)의 공개 URL. 카드가 없으면 null.
  String? get coverUrl => cards.isNotEmpty ? cards.first.publicUrl : null;

  /// 렌더링 가능한(공개 URL이 있는) 카드 이미지 URL 목록.
  List<String> get imageUrls => cards
      .map((c) => c.publicUrl)
      .whereType<String>()
      .where((u) => u.isNotEmpty)
      .toList();

  /// 행 `{ id, source, card_storage_paths: {...} }` 를 파싱한다.
  NewsCardResponse.fromJson(Map<String, dynamic> json) {
    _id = _asInt(json['id']);
    _source = json['source'] as String?;

    final raw = json['card_storage_paths'];
    final Map<String, dynamic> p = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};

    _bucket = p['bucket'] as String?;
    _folder = p['folder'] as String?;
    _generatedAt = p['generated_at'] as String?;

    final preview = p['preview'];
    if (preview is Map) {
      _previewUrl = preview['public_url'] as String?;
    }

    final list = p['cards'];
    if (list is List) {
      _cards = list
          .whereType<Map>()
          .map((e) => NewsCardImage.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => (a.index ?? 1 << 30).compareTo(b.index ?? 1 << 30));
    } else {
      _cards = null;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': _id,
      'source': _source,
      'card_storage_paths': <String, dynamic>{
        'bucket': _bucket,
        'folder': _folder,
        'generated_at': _generatedAt,
        'preview': _previewUrl == null ? null : {'public_url': _previewUrl},
        'cards': _cards?.map((c) => c.toJson()).toList(),
      },
    };
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 카드뉴스 한 장(이미지).
class NewsCardImage {
  /// 버킷 내 객체 경로
  String? _path;

  /// 카드 순번(1부터)
  int? _index;

  /// 공개 URL (cached_network_image 로 바로 로드 가능)
  String? _publicUrl;

  NewsCardImage({String? path, int? index, String? publicUrl}) {
    _path = path;
    _index = index;
    _publicUrl = publicUrl;
  }

  String? get path => _path;
  int? get index => _index;
  String? get publicUrl => _publicUrl;

  NewsCardImage.fromJson(Map<String, dynamic> json) {
    _path = json['path'] as String?;
    _index = NewsCardResponse._asInt(json['index']);
    _publicUrl = json['public_url'] as String?;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': _path,
      'index': _index,
      'public_url': _publicUrl,
    };
  }
}
