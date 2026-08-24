/// 금칙어 클라이언트 사전 검증.
///
/// 서버 트리거(`community_reject_banned_words`, `20260823000300`)가 최종
/// 권위이고 이쪽은 **왕복 없이 즉시 피드백**을 주기 위한 것이다. 따라서
/// 정규화 규칙이 서버와 정확히 같아야 한다 — 느슨하면 통과시켰다가 서버에서
/// 막히고, 빡빡하면 서버가 허용하는 글을 클라이언트가 막는다.
///
/// 서버 정의(`community_normalize_text`):
/// ```sql
/// regexp_replace(lower(coalesce(p_text, '')), '[^0-9a-z가-힣]', '', 'g')
/// ```
/// 공백·특수문자를 모두 지우므로 `ㅅ ㅂ` / `씨-발` 류 회피가 무력화된다.
/// 자음/모음 단독(ㅅ, ㅏ)은 `가-힣` 범위 밖이라 서버와 마찬가지로 제거된다.
class CommunityTextFilter {
  CommunityTextFilter._();

  /// 서버 `community_normalize_text()` 와 동일한 정규화.
  /// 이 정규식을 고칠 때는 반드시 마이그레이션의 SQL 도 같이 고친다.
  static final RegExp _stripPattern = RegExp(r'[^0-9a-z가-힣]');

  /// 소문자화 후 영숫자·완성형 한글만 남긴다.
  static String normalize(String? input) {
    if (input == null || input.isEmpty) return '';
    return input.toLowerCase().replaceAll(_stripPattern, '');
  }

  /// [text] 에 [bannedNorms] 중 하나라도 포함되면 그 정규화 금칙어를 돌려준다.
  ///
  /// [bannedNorms] 는 `community_banned_words.norm` 컬럼 값 목록이다 —
  /// 이미 서버에서 정규화된 값이므로 여기서 다시 정규화하지 않는다.
  /// 서버 트리거의 `position(w.norm in v_norm) > 0` 과 같은 부분 문자열 판정이다.
  static String? findBannedWord(String? text, List<String> bannedNorms) {
    if (bannedNorms.isEmpty) return null;
    final normalized = normalize(text);
    if (normalized.isEmpty) return null;
    for (final word in bannedNorms) {
      if (word.isEmpty) continue;
      if (normalized.contains(word)) return word;
    }
    return null;
  }

  /// 게시글 본문 검사 — 서버 트리거가 `title || ' ' || content` 를 한 덩어리로
  /// 정규화하므로 여기서도 같은 방식으로 합쳐서 본다.
  /// (공백은 정규화 과정에서 사라지므로 제목 끝과 본문 시작이 붙어 만들어지는
  /// 우연한 금칙어까지 서버와 동일하게 잡힌다.)
  static String? findBannedWordInPost({
    required String? title,
    required String? content,
    required List<String> bannedNorms,
  }) {
    return findBannedWord('${title ?? ''} ${content ?? ''}', bannedNorms);
  }
}
