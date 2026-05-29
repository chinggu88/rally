/// 선수 상세 프로필 응답 모델
///
/// Edge Function `get-player`가 반환하는 `player` 객체(`bwf_players` 테이블 1행)에
/// 1:1 매핑된다. PK(`id`)와 `name_display`를 제외하면 모두 서버에서 누락될 수
/// 있으므로 nullable로 선언한다.
class PlayerDetailResponse {
  /// bwf_players PK (bigint)
  int? _id;

  /// 표기용 전체 이름 (예: "SHI Yu Qi")
  String? _nameDisplay;

  /// 이름
  String? _firstName;

  /// 성
  String? _lastName;

  /// 성별 (예: "M", "F")
  String? _gender;

  /// 국가 3자 코드 (예: "CHN")
  String? _countryCode;

  /// 국가 표기명 (예: "China")
  String? _countryName;

  /// 생년월일 (ISO date 문자열, 예: "1996-02-15")
  String? _birthday;

  /// 키 (cm)
  int? _heightCm;

  /// 주로 쓰는 손 (예: "Right", "Left")
  String? _handedness;

  /// 프로필 사진 URL
  String? _photoUrl;

  /// 약력 / 에디토리얼 본문
  String? _bio;

  /// 코치
  String? _coach;

  /// 출생지
  String? _birthplace;

  /// 플레이 스타일 (예: "Aggressive")
  String? _plays;

  /// 통산 우승 횟수
  int? _careerTitles;

  /// 통산 승
  int? _careerWins;

  /// 통산 패
  int? _careerLosses;

  /// 소셜 링크 (jsonb) — { "instagram": "...", "twitter": "..." } 형태
  Map<String, dynamic>? _socialLinks;

  /// 외부 상세 페이지 URL (BWF 공식 등)
  String? _detailUrl;

  /// 원본 크롤 데이터 (jsonb)
  Map<String, dynamic>? _raw;

  /// 상세 정보 크롤 시각 (ISO datetime 문자열)
  String? _detailFetchedAt;

  /// 레코드 크롤 시각 (ISO datetime 문자열)
  String? _crawledAt;

  PlayerDetailResponse({
    int? id,
    String? nameDisplay,
    String? firstName,
    String? lastName,
    String? gender,
    String? countryCode,
    String? countryName,
    String? birthday,
    int? heightCm,
    String? handedness,
    String? photoUrl,
    String? bio,
    String? coach,
    String? birthplace,
    String? plays,
    int? careerTitles,
    int? careerWins,
    int? careerLosses,
    Map<String, dynamic>? socialLinks,
    String? detailUrl,
    Map<String, dynamic>? raw,
    String? detailFetchedAt,
    String? crawledAt,
  }) {
    _id = id;
    _nameDisplay = nameDisplay;
    _firstName = firstName;
    _lastName = lastName;
    _gender = gender;
    _countryCode = countryCode;
    _countryName = countryName;
    _birthday = birthday;
    _heightCm = heightCm;
    _handedness = handedness;
    _photoUrl = photoUrl;
    _bio = bio;
    _coach = coach;
    _birthplace = birthplace;
    _plays = plays;
    _careerTitles = careerTitles;
    _careerWins = careerWins;
    _careerLosses = careerLosses;
    _socialLinks = socialLinks;
    _detailUrl = detailUrl;
    _raw = raw;
    _detailFetchedAt = detailFetchedAt;
    _crawledAt = crawledAt;
  }

  int? get id => _id;
  set id(int? value) => _id = value;

  String? get nameDisplay => _nameDisplay;
  set nameDisplay(String? value) => _nameDisplay = value;

  String? get firstName => _firstName;
  set firstName(String? value) => _firstName = value;

  String? get lastName => _lastName;
  set lastName(String? value) => _lastName = value;

  String? get gender => _gender;
  set gender(String? value) => _gender = value;

  String? get countryCode => _countryCode;
  set countryCode(String? value) => _countryCode = value;

  String? get countryName => _countryName;
  set countryName(String? value) => _countryName = value;

  String? get birthday => _birthday;
  set birthday(String? value) => _birthday = value;

  int? get heightCm => _heightCm;
  set heightCm(int? value) => _heightCm = value;

  String? get handedness => _handedness;
  set handedness(String? value) => _handedness = value;

  String? get photoUrl => _photoUrl;
  set photoUrl(String? value) => _photoUrl = value;

  String? get bio => _bio;
  set bio(String? value) => _bio = value;

  String? get coach => _coach;
  set coach(String? value) => _coach = value;

  String? get birthplace => _birthplace;
  set birthplace(String? value) => _birthplace = value;

  String? get plays => _plays;
  set plays(String? value) => _plays = value;

  int? get careerTitles => _careerTitles;
  set careerTitles(int? value) => _careerTitles = value;

  int? get careerWins => _careerWins;
  set careerWins(int? value) => _careerWins = value;

  int? get careerLosses => _careerLosses;
  set careerLosses(int? value) => _careerLosses = value;

  Map<String, dynamic>? get socialLinks => _socialLinks;
  set socialLinks(Map<String, dynamic>? value) => _socialLinks = value;

  String? get detailUrl => _detailUrl;
  set detailUrl(String? value) => _detailUrl = value;

  Map<String, dynamic>? get raw => _raw;
  set raw(Map<String, dynamic>? value) => _raw = value;

  String? get detailFetchedAt => _detailFetchedAt;
  set detailFetchedAt(String? value) => _detailFetchedAt = value;

  String? get crawledAt => _crawledAt;
  set crawledAt(String? value) => _crawledAt = value;

  /// 생년월일 문자열을 DateTime으로 파싱 (실패 시 null).
  DateTime? get birthdayDate =>
      _birthday == null ? null : DateTime.tryParse(_birthday!);

  /// 생년월일 기준 만 나이 (계산 불가 시 null).
  int? get age {
    final dob = birthdayDate;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years -= 1;
    }
    return years < 0 ? null : years;
  }

  PlayerDetailResponse.fromJson(Map<String, dynamic> json) {
    _id = _asInt(json['id']);
    _nameDisplay = json['name_display'] as String?;
    _firstName = json['first_name'] as String?;
    _lastName = json['last_name'] as String?;
    _gender = json['gender'] as String?;
    _countryCode = json['country_code'] as String?;
    _countryName = json['country_name'] as String?;
    _birthday = json['birthday'] as String?;
    _heightCm = _asInt(json['height_cm']);
    _handedness = json['handedness'] as String?;
    _photoUrl = json['photo_url'] as String?;
    _bio = json['bio'] as String?;
    _coach = json['coach'] as String?;
    _birthplace = json['birthplace'] as String?;
    _plays = json['plays'] as String?;
    _careerTitles = _asInt(json['career_titles']);
    _careerWins = _asInt(json['career_wins']);
    _careerLosses = _asInt(json['career_losses']);
    _socialLinks = _asMap(json['social_links']);
    _detailUrl = json['detail_url'] as String?;
    _raw = _asMap(json['raw']);
    _detailFetchedAt = json['detail_fetched_at'] as String?;
    _crawledAt = json['crawled_at'] as String?;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = _id;
    data['name_display'] = _nameDisplay;
    data['first_name'] = _firstName;
    data['last_name'] = _lastName;
    data['gender'] = _gender;
    data['country_code'] = _countryCode;
    data['country_name'] = _countryName;
    data['birthday'] = _birthday;
    data['height_cm'] = _heightCm;
    data['handedness'] = _handedness;
    data['photo_url'] = _photoUrl;
    data['bio'] = _bio;
    data['coach'] = _coach;
    data['birthplace'] = _birthplace;
    data['plays'] = _plays;
    data['career_titles'] = _careerTitles;
    data['career_wins'] = _careerWins;
    data['career_losses'] = _careerLosses;
    data['social_links'] = _socialLinks;
    data['detail_url'] = _detailUrl;
    data['raw'] = _raw;
    data['detail_fetched_at'] = _detailFetchedAt;
    data['crawled_at'] = _crawledAt;
    return data;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
