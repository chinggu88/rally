/// BWF 이미지 URL 정규화 유틸.
///
/// BWF 이미지(선수 사진·국기·대회 로고)는 `https://img.bwfbadminton.com/...` 로
/// 제공되지만, 이 호스트는 Cloudflare 봇/핫링크 보호 뒤에 있어 앱에서 직접 로드하면
/// 403(Forbidden)이 반환된다.
///
/// 실제 자산은 Cloudinary(`res.cloudinary.com/badminton/...`)에 호스팅되어 있고
/// 경로는 동일하다. 따라서 호스트만 치환하면 Cloudflare를 우회해 정상 로드된다.
///
/// `extranet.bwfbadminton.com/images/profile_male.jpg`(및 female) 같은
/// "사진 없음" placeholder는 Cloudflare 403 + HTML 본문을 반환해 Android
/// ImageDecoder가 `'unimplemented'`로 죽인다. 앱 측 폴백 아이콘이 더 깔끔하므로
/// 이런 placeholder는 null로 떨군다.
library;

const String _bwfImgHost = 'https://img.bwfbadminton.com/';
const String _cloudinaryHost = 'https://res.cloudinary.com/badminton/';

const Set<String> _bwfProfilePlaceholders = <String>{
  'https://extranet.bwfbadminton.com/images/profile_male.jpg',
  'https://extranet.bwfbadminton.com/images/profile_female.jpg',
};

/// `img.bwfbadminton.com` 호스트를 Cloudinary 원본 호스트로 치환한다.
///
/// - 해당 호스트가 아니거나 null/빈 값이면 입력을 그대로 반환한다.
/// - BWF "사진 없음" placeholder는 null로 치환한다 (앱 폴백 사용).
String? bwfImageUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  if (_bwfProfilePlaceholders.contains(url)) return null;
  if (url.startsWith(_bwfImgHost)) {
    return _cloudinaryHost + url.substring(_bwfImgHost.length);
  }
  return url;
}
