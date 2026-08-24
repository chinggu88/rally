import 'package:supabase_flutter/supabase_flutter.dart';

/// 클라이언트가 직접 판정한 입력 오류.
///
/// 서버까지 보내지 않고 즉시 되돌려 줄 때 쓴다(글자 수 초과, 이미지 용량 초과,
/// 금칙어 사전 검증 등). [message] 는 그대로 사용자에게 보여주므로 반드시
/// 완성된 한국어 문장이어야 한다 — 내부 상태를 담지 않는다.
class CommunityValidationException implements Exception {
  const CommunityValidationException(this.message);

  final String message;

  @override
  String toString() => 'CommunityValidationException: $message';
}

/// 커뮤니티 관련 Supabase 예외를 사용자에게 보여줄 한국어 문구로 변환한다.
///
/// 서버(마이그레이션 `20260823000100`~`000400`)의 `raise exception ... using hint`
/// 값과 PostgREST 에러 코드를 그대로 받아 매핑한다. 매핑되지 않는 예외는
/// 원문을 노출하지 않고 범용 문구로 덮는다.
String communityErrorMessage(Object error) {
  if (error is CommunityValidationException) {
    return error.message;
  }
  if (error is PostgrestException) {
    switch (error.hint) {
      case 'banned_word':
        return '사용할 수 없는 표현이 포함되어 있습니다.';
      case 'depth_exceeded':
        return '대댓글에는 답글을 달 수 없습니다.';
      case 'parent_removed':
        return '삭제된 댓글에는 답글을 달 수 없습니다.';
      case 'forbidden':
        return '권한이 없습니다.';
    }
    switch (error.code) {
      case '23505':
        // unique_violation 은 한 곳에서만 나지 않는다 — 닉네임 유니크 인덱스,
        // 신고 중복(`community_reports_uq_*`), 재차단(`user_blocks` PK)이
        // 모두 같은 코드다. 코드 하나에 문구 하나를 박아 두면 재신고에
        // "이미 사용 중인 닉네임입니다" 가 뜬다.
        //
        // PostgREST 는 위반한 제약 이름을 message/details 에 그대로 실어
        // 보내므로(`duplicate key value violates unique constraint "..."`)
        // 그것으로 구분한다. 새 유니크 제약을 추가하면 여기에도 한 줄 넣는다.
        return _duplicateMessage('${error.message} ${error.details ?? ''}');
      case '23514':
        // CHECK 제약 위반. 제목 1~100자 / 본문 1~5000자 / 이미지 5장 제한이
        // 클라이언트 검증을 빠져나갔을 때 여기로 온다.
        return '입력한 내용이 형식에 맞지 않습니다.';
      case '42501':
        return '커뮤니티 이용규칙 동의가 필요합니다.';
    }
  }
  if (error is StorageException) {
    // 버킷 제약(5MB / jpeg·png·webp·heic)은 스토리지 계층에서 걸린다.
    final status = error.statusCode;
    if (status == '413') return '이미지 용량이 너무 큽니다. (최대 5MB)';
    if (status == '415') return '지원하지 않는 이미지 형식입니다.';
    return '이미지 업로드에 실패했습니다. 잠시 후 다시 시도해주세요.';
  }
  return '잠시 후 다시 시도해주세요.';
}

/// `23505` 를 위반한 제약 이름으로 갈라 문구를 고른다.
///
/// [haystack] 은 `PostgrestException` 의 message + details 를 이어 붙인 값이다.
/// 어느 쪽에 제약 이름이 실릴지는 PostgREST 버전에 따라 다르므로 둘 다 본다.
///
/// 마지막 fallback 을 닉네임 문구로 두지 않는 것이 중요하다 — 알 수 없는
/// 유니크 위반에 엉뚱한 안내를 하느니 중립적인 문장이 낫다.
String _duplicateMessage(String haystack) {
  if (haystack.contains('community_reports_uq')) {
    return '이미 신고한 콘텐츠입니다.';
  }
  if (haystack.contains('user_blocks')) {
    return '이미 차단한 사용자입니다.';
  }
  // 부분 유니크 인덱스 `profiles_nickname_norm_key`. 인덱스 이름이 실리지
  // 않는 경우까지 받도록 컬럼명(`nickname`)도 함께 본다.
  if (haystack.contains('nickname')) {
    return '이미 사용 중인 닉네임입니다.';
  }
  return '이미 등록된 내용입니다.';
}
