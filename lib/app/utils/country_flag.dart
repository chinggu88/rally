/// 국가 코드(ISO3) → 이모지 국기 변환 유틸.
///
/// BWF 데이터는 3자 국가코드(예: "KOR", "DEN")를 사용하므로,
/// 이를 ISO2(2자)로 매핑한 뒤 regional-indicator 유니코드 조합으로 국기 이모지를 만든다.
/// 네트워크 요청 없이 동작하며, 매핑되지 않는 코드는 빈 문자열을 반환한다.
library;

/// 국가코드 → ISO2 매핑.
///
/// BWF `country_code`는 대부분 ISO 3166 alpha-3(예: DNK, TWN, IDN)이지만
/// 일부 종목은 IOC 코드(예: INA, TPE, GER)로 들어온다. 두 체계를 모두 수용한다.
/// 누락 코드는 [flagEmoji]에서 빈 문자열로 graceful 처리된다.
const Map<String, String> _iso3ToIso2 = <String, String>{
  // East Asia
  'KOR': 'KR', // Korea
  'PRK': 'KP', // North Korea
  'JPN': 'JP', // Japan
  'CHN': 'CN', // China
  'TWN': 'TW', 'TPE': 'TW', // Chinese Taipei (ISO/IOC)
  'HKG': 'HK', // Hong Kong
  'MAC': 'MO', // Macau
  'MNG': 'MN', // Mongolia
  // Southeast / South Asia
  'IDN': 'ID', 'INA': 'ID', // Indonesia (ISO/IOC)
  'MYS': 'MY', 'MAS': 'MY', // Malaysia (ISO/IOC)
  'THA': 'TH', // Thailand
  'IND': 'IN', // India
  'SGP': 'SG', 'SIN': 'SG', // Singapore (ISO/IOC)
  'VNM': 'VN', 'VIE': 'VN', // Vietnam (ISO/IOC)
  'PHL': 'PH', 'PHI': 'PH', // Philippines (ISO/IOC)
  'MMR': 'MM', 'MYA': 'MM', // Myanmar (ISO/IOC)
  'LKA': 'LK', 'SRI': 'LK', // Sri Lanka (ISO/IOC)
  'MDV': 'MV', // Maldives
  'KAZ': 'KZ', // Kazakhstan
  // Europe
  'DNK': 'DK', 'DEN': 'DK', // Denmark (ISO/IOC)
  'ESP': 'ES', // Spain
  'FRA': 'FR', // France
  'DEU': 'DE', 'GER': 'DE', // Germany (ISO/IOC)
  'GBR': 'GB', 'ENG': 'GB', 'SCO': 'GB', 'WAL': 'GB', // GB / Home Nations
  'NLD': 'NL', 'NED': 'NL', // Netherlands (ISO/IOC)
  'IRL': 'IE', // Ireland
  'BEL': 'BE', // Belgium
  'CHE': 'CH', 'SUI': 'CH', // Switzerland (ISO/IOC)
  'AUT': 'AT', // Austria
  'SWE': 'SE', // Sweden
  'NOR': 'NO', // Norway
  'FIN': 'FI', // Finland
  'PRT': 'PT', 'POR': 'PT', // Portugal (ISO/IOC)
  'ITA': 'IT', // Italy
  'CZE': 'CZ', // Czechia
  'POL': 'PL', // Poland
  'RUS': 'RU', // Russia
  'UKR': 'UA', // Ukraine
  'TUR': 'TR', // Turkey
  'BGR': 'BG', 'BUL': 'BG', // Bulgaria (ISO/IOC)
  'EST': 'EE', // Estonia
  'LTU': 'LT', // Lithuania
  'LVA': 'LV', // Latvia
  'SVK': 'SK', // Slovakia
  'SVN': 'SI', 'SLO': 'SI', // Slovenia (ISO/IOC)
  'HRV': 'HR', 'CRO': 'HR', // Croatia (ISO/IOC)
  'HUN': 'HU', // Hungary
  'GRC': 'GR', 'GRE': 'GR', // Greece (ISO/IOC)
  'ISL': 'IS', // Iceland
  'CYP': 'CY', // Cyprus
  'ISR': 'IL', // Israel
  // Americas
  'USA': 'US', // United States
  'CAN': 'CA', // Canada
  'BRA': 'BR', // Brazil
  'MEX': 'MX', // Mexico
  'PER': 'PE', // Peru
  'GTM': 'GT', 'GUA': 'GT', // Guatemala (ISO/IOC)
  // Oceania
  'AUS': 'AU', // Australia
  'NZL': 'NZ', // New Zealand
  // Africa / Middle East
  'EGY': 'EG', // Egypt
  'ZAF': 'ZA', 'RSA': 'ZA', // South Africa (ISO/IOC)
  'NGA': 'NG', 'NGR': 'NG', // Nigeria (ISO/IOC)
  'MUS': 'MU', 'MRI': 'MU', // Mauritius (ISO/IOC)
  'DZA': 'DZ', 'ALG': 'DZ', // Algeria (ISO/IOC)
};

/// ISO3 국가코드 → 이모지 국기.
///
/// 매핑되지 않거나 입력이 비어있으면 빈 문자열을 반환한다(호출부에서 폴백 처리).
String flagEmoji(String? iso3) {
  if (iso3 == null) return '';
  final code = iso3.trim().toUpperCase();
  if (code.isEmpty) return '';

  final iso2 = _iso3ToIso2[code];
  if (iso2 == null || iso2.length != 2) return '';

  // 'A'(0x41) → regional indicator 'A'(0x1F1E6) 오프셋.
  const int base = 0x1F1E6 - 0x41;
  final first = iso2.codeUnitAt(0) + base;
  final second = iso2.codeUnitAt(1) + base;
  return String.fromCharCode(first) + String.fromCharCode(second);
}
