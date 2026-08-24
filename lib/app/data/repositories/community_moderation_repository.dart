import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blocked_user_response.dart';
import '../models/community_report_response.dart';
import '../models/create_community_report_parameter.dart';

/// 커뮤니티 작성 자격(약관 동의 · 닉네임 · 이용 정지) · 금칙어 사전 ·
/// 신고 · 차단 · 운영자 조치를 다루는 레포지토리.
///
/// 서버 쪽에서 `community_reports` / `user_blocks` / `app_admins` 가 같은
/// 모더레이션 묶음이라 한 파일에 모아 둔다.
class CommunityModerationRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// 현재 이용규칙 버전.
  ///
  /// **DB `community_eula_version()` 과 반드시 일치해야 한다**
  /// (`20260823000100_community_moderation_primitives.sql:219`).
  /// 어긋나면 `community_can_write()` 가 false 를 돌려주고
  /// **전 사용자가 글을 쓸 수 없게 된다.**
  /// 버전을 올릴 때는 두 곳을 한 커밋에서 바꾸고 **DB 를 먼저 배포**한다.
  static const String eulaVersion = '2026-08-23';

  /// 약관 문서 코드. `user_agreements.doc` 는 ('community_eula','privacy') 만 허용.
  static const String eulaDoc = 'community_eula';

  /// 이용규칙 원문 애셋 경로.
  ///
  /// 동의 시트와 상시 열람 화면(내정보 → 커뮤니티 이용규칙)이 같은 문서를
  /// 읽어야 해서 한곳에 둔다 — 두 화면이 서로 다른 문서를 보여주면
  /// "동의한 내용"과 "열람 가능한 내용"이 어긋난다.
  static const String eulaAssetPath = 'assets/docs/community_eula.md';

  static const String _agreementsTable = 'user_agreements';
  static const String _bannedWordsTable = 'community_banned_words';
  static const String _profilesTable = 'profiles';
  static const String _reportsTable = 'community_reports';
  static const String _blocksTable = 'user_blocks';
  static const String _publicProfilesView = 'public_profiles';

  /// 프로세스 수명 동안 유지하는 금칙어 캐시.
  ///
  /// 사전은 수십 건 규모이고 작성 화면에 들어올 때마다 다시 받을 이유가 없다.
  /// 서버 트리거가 최종 권위라 캐시가 조금 낡아도 안전 방향으로만 틀린다
  /// (놓친 금칙어는 서버가 잡는다).
  static List<String>? _bannedWordCache;

  /// 현재 사용자가 **현재 버전** 이용규칙에 동의했는지.
  ///
  /// 버전을 `eq` 로 걸기 때문에 서버가 버전을 올리면 자동으로 false 가 되어
  /// 재동의 흐름을 탄다.
  Future<bool> hasAgreedToEula() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final row =
          await _client
              .from(_agreementsTable)
              .select('user_id')
              .eq('doc', eulaDoc)
              .eq('version', eulaVersion)
              .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.hasAgreedToEula Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  /// 이용규칙 동의 기록.
  ///
  /// PK 가 `(user_id, doc)` 라 재동의(버전 갱신)는 새 행이 아니라 upsert 다.
  /// `user_agreements` 에 UPDATE 권한을 열어 둔 이유가 이것이다.
  Future<void> agreeToEula() async {
    final user = _requireUser();
    try {
      await _client.from(_agreementsTable).upsert(<String, dynamic>{
        'user_id': user.id,
        'doc': eulaDoc,
        'version': eulaVersion,
        'agreed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,doc');
    } on PostgrestException catch (e) {
      log('CommunityModerationRepository.agreeToEula Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 차단 심각도 금칙어의 **정규화값(`norm`)** 목록.
  ///
  /// `word` 가 아니라 `norm` 을 읽는 것이 중요하다 — 서버 트리거도 `norm` 으로
  /// 비교하므로 클라이언트가 원문을 다시 정규화하면 규칙이 어긋날 수 있다.
  Future<List<String>> fetchBannedWords({bool forceRefresh = false}) async {
    final cached = _bannedWordCache;
    if (!forceRefresh && cached != null) return cached;

    try {
      final rows = await _client
          .from(_bannedWordsTable)
          .select('norm')
          .eq('severity', 'block');

      final words =
          (rows as List)
              .map((e) => (e as Map)['norm']?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
      _bannedWordCache = words;
      return words;
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.fetchBannedWords Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  /// 작성 게이트 판정에 필요한 내 프로필 조각 (닉네임 · 이용 정지 만료 시각).
  ///
  /// `community_can_write()` RPC 를 쓰지 않고 직접 읽는 이유: RPC 는 bool 하나만
  /// 돌려주므로 "약관 미동의"와 "이용 정지"를 구분할 수 없다. 두 경우의 안내가
  /// 완전히 달라서(시트 노출 vs 정지 안내) 구분이 필요하다.
  Future<CommunityWriteEligibility> fetchWriteEligibility() async {
    final user = _requireUser();
    try {
      final row =
          await _client
              .from(_profilesTable)
              .select('nickname, community_banned_until')
              .eq('id', user.id)
              .maybeSingle();

      final nickname = (row?['nickname'] as String?)?.trim();
      final bannedUntilRaw = row?['community_banned_until'] as String?;
      return CommunityWriteEligibility(
        nickname: (nickname == null || nickname.isEmpty) ? null : nickname,
        bannedUntil:
            bannedUntilRaw == null
                ? null
                : DateTime.tryParse(bannedUntilRaw)?.toLocal(),
      );
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.fetchWriteEligibility Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  /// 닉네임 중복 사전 확인 (온보딩 시트의 실시간 피드백용).
  ///
  /// 최종 판정은 부분 유니크 인덱스 `profiles_nickname_norm_key` 의 23505 다.
  /// 여기서 false 가 나와도 저장이 실패할 수 있다:
  ///   · `public_profiles` 뷰에 `nickname_norm` 이 없어 `ilike` 로 근사한다
  ///     (앞뒤 공백이 들어간 기존 닉네임은 놓칠 수 있다)
  ///   · 확인과 저장 사이에 다른 사용자가 선점할 수 있다
  /// 즉 이 메서드는 "즉시 피드백"이지 "보장"이 아니다.
  Future<bool> isNicknameTaken(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return false;

    // 와일드카드로 해석될 수 있는 문자가 있으면 아예 물어보지 않는다.
    // `%` `_` 는 SQL LIKE 의 와일드카드이고, PostgREST 는 `*` 도 `%` 로 바꾼다.
    // 이스케이프를 시도하면 두 계층의 처리 순서에 의존하게 되므로, 흔치 않은
    // 이 경우는 사전 확인을 건너뛰고 저장 시점의 23505 에 맡긴다.
    if (_wildcardPattern.hasMatch(trimmed)) return false;

    final myId = _client.auth.currentUser?.id;
    try {
      var query = _client
          .from('public_profiles')
          .select('id')
          .ilike('nickname', trimmed);
      if (myId != null) {
        query = query.neq('id', myId);
      }
      final rows = await query.limit(1);
      return (rows as List).isNotEmpty;
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.isNicknameTaken Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  static final RegExp _wildcardPattern = RegExp(r'[%_*\\]');

  // ── 신고 ────────────────────────────────────────────────────────────────

  /// 신고 접수.
  ///
  /// INSERT 하나가 전부다. 자동 숨김(사유별 1건/3건 차등)과 운영자 FCM 푸시는
  /// `community_on_report` 트리거가 서버에서 처리하므로 클라이언트가 임계값을
  /// 알거나 흉내 낼 필요가 없다.
  ///
  /// 같은 신고자가 같은 대상을 다시 신고하면 부분 유니크 인덱스
  /// (`community_reports_uq_*`)가 `23505` 로 막는다. 그대로 rethrow 하면 되고,
  /// "이미 신고한 콘텐츠입니다" 로 바꾸는 것은 `communityErrorMessage()` 다 —
  /// 23505 는 닉네임·차단에서도 나므로 문구 판정을 한곳에 모아 둔다.
  Future<void> createReport(CreateCommunityReportParameter param) async {
    final user = _requireUser();
    try {
      await _client.from(_reportsTable).insert(<String, dynamic>{
        ...param.toJson(),
        'reporter_id': user.id,
      });
    } on PostgrestException catch (e) {
      log('CommunityModerationRepository.createReport Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 특정 콘텐츠의 **미처리** 신고 목록. 운영자 전용 경로다.
  ///
  /// 일반 사용자가 호출하면 `cr_select_own` 정책 때문에 자기가 낸 신고만
  /// 돌아온다(에러가 아니라 빈/부분 결과). 호출부는 [isAppAdmin] 으로 이미
  /// 걸러진 상태에서만 쓴다.
  Future<List<CommunityReportResponse>> listPendingReports({
    String? postId,
    String? commentId,
  }) async {
    if ((postId == null || postId.isEmpty) &&
        (commentId == null || commentId.isEmpty)) {
      return const <CommunityReportResponse>[];
    }
    try {
      var query = _client.from(_reportsTable).select().eq('status', 'pending');
      if (postId != null && postId.isNotEmpty) {
        query = query.eq('post_id', postId);
      } else {
        query = query.eq('comment_id', commentId!);
      }
      final rows = await query.order('created_at');
      return (rows as List)
          .map(
            (e) => CommunityReportResponse.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.listPendingReports Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  // ── 차단 ────────────────────────────────────────────────────────────────

  /// 사용자 차단.
  ///
  /// 목록 필터링은 클라이언트가 하지 않는다 — `community_is_blocked()` 를
  /// 참조하는 RLS 가 서버에서 양방향으로 걸러 주므로, 차단 직후 목록을 다시
  /// 부르기만 하면 된다.
  ///
  /// PK 가 `(blocker_id, blocked_id)` 라 재차단은 `23505` 다. 이미 차단된
  /// 상태를 실패로 알릴 이유가 없어 멱등 처리한다(좋아요 INSERT 와 같은 정책).
  Future<void> blockUser(String userId) async {
    final user = _requireUser();
    try {
      await _client.from(_blocksTable).insert(<String, dynamic>{
        'blocker_id': user.id,
        'blocked_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      log('CommunityModerationRepository.blockUser Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 차단 해제. 대상 행이 없어도 성공으로 본다(멱등).
  Future<void> unblockUser(String userId) async {
    final user = _requireUser();
    try {
      await _client
          .from(_blocksTable)
          .delete()
          .eq('blocker_id', user.id)
          .eq('blocked_id', userId);
    } on PostgrestException catch (e) {
      log('CommunityModerationRepository.unblockUser Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 내가 차단한 사용자 목록 (최근 차단 순).
  ///
  /// `user_blocks` 와 `public_profiles` 사이에 FK 가 없어 PostgREST 임베딩이
  /// 되지 않으므로 두 번 조회해 붙인다 (`ChatMessageRepository._hydrateProfiles`
  /// 패턴). 프로필 조회 실패는 치명적이지 않아 닉네임 없이 돌려준다 —
  /// 차단 해제 버튼은 `blocked_id` 만 있으면 동작한다.
  Future<List<BlockedUserResponse>> listBlockedUsers() async {
    final user = _requireUser();
    try {
      final rows = await _client
          .from(_blocksTable)
          .select('blocked_id, created_at')
          .eq('blocker_id', user.id)
          .order('created_at', ascending: false);

      final blocks =
          (rows as List)
              .map(
                (e) => BlockedUserResponse.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
      return await _hydrateProfiles(blocks);
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.listBlockedUsers Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  Future<List<BlockedUserResponse>> _hydrateProfiles(
    List<BlockedUserResponse> blocks,
  ) async {
    if (blocks.isEmpty) return blocks;
    final ids =
        blocks
            .map((b) => b.blockedId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    if (ids.isEmpty) return blocks;

    try {
      final profiles = await _client
          .from(_publicProfilesView)
          .select('id, nickname, avatar_url')
          .inFilter('id', ids);

      final byId = <String, Map<String, dynamic>>{};
      for (final p in (profiles as List)) {
        final map = Map<String, dynamic>.from(p as Map);
        final id = map['id'] as String?;
        if (id != null) byId[id] = map;
      }
      return blocks.map((b) {
        final profile = byId[b.blockedId];
        if (profile == null) return b;
        return b.copyWithProfile(
          nickname: profile['nickname'] as String?,
          avatarUrl: profile['avatar_url'] as String?,
        );
      }).toList();
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository._hydrateProfiles Postgrest: ${e.message}',
      );
      return blocks;
    }
  }

  // ── 운영자 조치 ─────────────────────────────────────────────────────────

  /// 현재 사용자가 운영자인지.
  ///
  /// `app_admins` 는 RLS ON + 정책 0개라 클라이언트가 직접 읽을 수 없다
  /// (의도된 설계). 판정은 security definer 함수로만 한다.
  ///
  /// 실패하면 false 다 — 운영자 항목이 안 보이는 쪽이 안전한 실패 방향이고,
  /// 설령 조회에 성공해 항목이 떠도 실제 조치는 서버가 다시 검사한다.
  Future<bool> isAppAdmin() async {
    if (_client.auth.currentUser == null) return false;
    try {
      final result = await _client.rpc<dynamic>('is_app_admin');
      return result == true;
    } catch (e) {
      log('CommunityModerationRepository.isAppAdmin error: $e');
      return false;
    }
  }

  /// 게시글 숨김/복구/강제 삭제.
  ///
  /// **반드시 RPC 다.** `status` 컬럼에는 GRANT UPDATE 가 없어
  /// `.from().update({'status': ...})` 는 RLS 를 통과해도 42501 로 막힌다
  /// (`20260823000400_community_feed_views.sql:203`).
  Future<void> setPostStatus(String postId, String status) async {
    try {
      await _client.rpc<dynamic>(
        'community_set_post_status',
        params: <String, dynamic>{'p_id': postId, 'p_status': status},
      );
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.setPostStatus Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  /// 댓글 숨김/복구/강제 삭제. [setPostStatus] 와 같은 이유로 RPC 다.
  Future<void> setCommentStatus(String commentId, String status) async {
    try {
      await _client.rpc<dynamic>(
        'community_set_comment_status',
        params: <String, dynamic>{'p_id': commentId, 'p_status': status},
      );
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.setCommentStatus Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  /// 작성자 커뮤니티 이용 정지. 정지 중에는 `community_can_write()` 가 false 라
  /// 글·댓글 작성이 막힌다(읽기는 그대로).
  Future<void> banUser(String userId, int days) async {
    try {
      await _client.rpc<dynamic>(
        'community_ban_user',
        params: <String, dynamic>{'p_user_id': userId, 'p_days': days},
      );
    } on PostgrestException catch (e) {
      log('CommunityModerationRepository.banUser Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 이용 정지 해제.
  Future<void> unbanUser(String userId) async {
    try {
      await _client.rpc<dynamic>(
        'community_unban_user',
        params: <String, dynamic>{'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      log('CommunityModerationRepository.unbanUser Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 신고 종결. [status] 는 `actioned` 또는 `rejected`.
  ///
  /// 이미 처리된 신고에 다시 호출하면 `already_resolved` 로 거절된다.
  Future<void> resolveReport(
    String reportId,
    String status, {
    String? note,
  }) async {
    try {
      await _client.rpc<dynamic>(
        'community_resolve_report',
        params: <String, dynamic>{
          'p_report_id': reportId,
          'p_status': status,
          'p_note': note,
        },
      );
    } on PostgrestException catch (e) {
      log(
        'CommunityModerationRepository.resolveReport Postgrest: ${e.message}',
      );
      rethrow;
    }
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user;
  }
}

/// [CommunityModerationRepository.fetchWriteEligibility] 결과.
class CommunityWriteEligibility {
  const CommunityWriteEligibility({this.nickname, this.bannedUntil});

  /// 설정된 닉네임. 미설정이면 null — 온보딩 시트에서 입력받아야 한다.
  final String? nickname;

  /// 이용 정지 만료 시각. null 이거나 과거면 정지 상태가 아니다.
  final DateTime? bannedUntil;

  /// 지금 이용 정지 중인지.
  bool get isBanned {
    final until = bannedUntil;
    return until != null && until.isAfter(DateTime.now());
  }
}
