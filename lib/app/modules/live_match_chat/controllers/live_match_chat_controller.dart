import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../theme/app_colors.dart';
import '../../../data/models/chat_message_response.dart';
import '../../../data/models/create_community_report_parameter.dart';
import '../../../data/repositories/chat_message_repository.dart';
import '../../../data/repositories/community_moderation_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/community_error.dart';
import '../../community/views/widgets/community_report_sheet.dart';

/// 라이브 매치 채팅방 컨트롤러.
///
/// 진입 시 비로그인이면 즉시 로그인 화면으로 리다이렉트한다.
/// 메시지 로드 → Realtime 구독 → 사용자 입력 INSERT 순으로 동작.
class LiveMatchChatController extends GetxController {
  static const int pageSize = 50;
  static const int maxContentLen = 500;

  final ChatMessageRepository _repository = Get.find<ChatMessageRepository>();

  /// 신고·차단은 커뮤니티와 **같은 저장소를 공유**한다(`community_reports` /
  /// `user_blocks`). 채팅 전용 테이블을 만들면 커뮤니티에서 차단한 사용자가
  /// 채팅에서는 다시 보이게 되므로 레포지토리를 그대로 재사용한다.
  final CommunityModerationRepository _moderationRepository =
      Get.find<CommunityModerationRepository>();

  // ── arguments 캐시 ──────────────────────────────────────────
  late final int liveMatchId;
  late final List<String> team1Names;
  late final List<String> team2Names;
  late final String? team1Country;
  late final String? team2Country;
  late final String? eventName;
  late final String? roundName;
  late final String? tournamentName;
  late final String? courtName;
  late final String? scoreSnapshot;

  // ── 상태 ────────────────────────────────────────────────────
  /// 시간 오름차순 (오래된 → 최신).
  final _messages = <ChatMessageResponse>[].obs;
  List<ChatMessageResponse> get messages => _messages;

  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final _isLoadingMore = false.obs;
  bool get isLoadingMore => _isLoadingMore.value;

  final _hasMore = true.obs;
  bool get hasMore => _hasMore.value;

  final _isSending = false.obs;
  bool get isSending => _isSending.value;

  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;

  /// 채팅방에 현재 접속 중인 사용자 수 (Realtime Presence 기반).
  final _onlineCount = 0.obs;
  int get onlineCount => _onlineCount.value;

  /// 실시간 스코어. 진입 시 arguments의 score 스냅샷으로 시작하고
  /// bwf_live_matches UPDATE 이벤트로 갱신된다.
  final _liveScore = RxnString();
  String? get liveScore => _liveScore.value;

  /// 라이브 스코어 가리기 (AppBar 체크박스로 토글).
  final _hideLiveScore = false.obs;
  bool get hideLiveScore => _hideLiveScore.value;
  void toggleHideLiveScore(bool? value) =>
      _hideLiveScore.value = value ?? false;

  final composer = TextEditingController();
  String? get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  RealtimeChannel? _channel;

  /// 내가 차단한 사용자 id 집합.
  ///
  /// 커뮤니티와 달리 **서버가 걸러 주지 않는다** — `live_match_chat_messages` 의
  /// SELECT 정책은 `lmc_select_all (using true)` 라 RLS 가 차단을 반영하지
  /// 않는다. 그래서 초기 로드 · 더 불러오기 · Realtime INSERT 세 경로 모두에서
  /// 클라이언트가 직접 걸러야 한다.
  final Set<String> _blockedUserIds = <String>{};

  /// 차단 목록 조회 완료 future.
  ///
  /// 조회가 끝나기 전에 도착한 메시지가 필터를 건너뛰지 않도록 각 경로가 이
  /// future 를 먼저 기다린다. 조회에 실패해도 완료되며(필터만 미적용) 채팅
  /// 자체는 정상 동작한다.
  Future<void>? _blockedReady;

  @override
  void onInit() {
    super.onInit();
    _parseArguments();

    if (currentUserId == null) {
      // 진입 시 로그인 강제. 채팅방 자체를 닫고 로그인 화면으로.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offNamed(Routes.LOGIN);
      });
      return;
    }

    _blockedReady = _loadBlockedUsers();
    loadInitial();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _unsubscribeRealtime();
    composer.dispose();
    super.onClose();
  }

  void _parseArguments() {
    final args = Get.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    liveMatchId = (map['live_match_id'] as num?)?.toInt() ?? 0;
    team1Names = _stringList(map['team1_names']);
    team2Names = _stringList(map['team2_names']);
    team1Country = map['team1_country'] as String?;
    team2Country = map['team2_country'] as String?;
    eventName = map['event_name'] as String?;
    roundName = map['round_name'] as String?;
    tournamentName = map['tournament_name'] as String?;
    courtName = map['court_name'] as String?;
    scoreSnapshot = map['score'] as String?;
    _liveScore.value = scoreSnapshot;
  }

  static List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const <String>[];
  }

  // ── 메시지 로드 ──────────────────────────────────────────────

  Future<void> loadInitial() async {
    if (liveMatchId == 0) {
      _errorMessage.value = '잘못된 채팅방입니다.';
      return;
    }
    try {
      _isLoading.value = true;
      _errorMessage.value = null;
      final list = await _repository.listMessages(
        liveMatchId: liveMatchId,
        limit: pageSize,
      );
      await _blockedReady;
      // DESC로 받은 것을 ASC로 뒤집어 저장 (오래된 → 최신)
      _messages.assignAll(_withoutBlocked(list.reversed));
      // hasMore 는 **걸러내기 전** 개수로 판정한다 — 차단 메시지가 많은 페이지에서
      // 필터 후 개수로 보면 아직 남은 메시지가 있는데도 끝으로 오인한다.
      _hasMore.value = list.length >= pageSize;
    } catch (e) {
      log('LiveMatchChatController.loadInitial error: $e');
      _errorMessage.value = '메시지를 불러오지 못했습니다.';
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore.value || !_hasMore.value || _messages.isEmpty) return;
    try {
      _isLoadingMore.value = true;
      final oldest = _messages.first.createdAt;
      final list = await _repository.listMessages(
        liveMatchId: liveMatchId,
        before: oldest,
        limit: pageSize,
      );
      if (list.isEmpty) {
        _hasMore.value = false;
        return;
      }
      await _blockedReady;
      // 새로 받은 페이지는 DESC. 앞쪽(오래된 영역)에 ASC로 prepend.
      _messages.insertAll(0, _withoutBlocked(list.reversed));
      _hasMore.value = list.length >= pageSize;
    } catch (e) {
      log('LiveMatchChatController.loadMore error: $e');
    } finally {
      _isLoadingMore.value = false;
    }
  }

  // ── 메시지 전송 ──────────────────────────────────────────────

  Future<void> sendComposerMessage() async {
    final raw = composer.text;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > maxContentLen) {
      Get.snackbar('전송 실패', '메시지는 $maxContentLen자 이하여야 합니다.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (currentUserId == null) {
      Get.offNamed(Routes.LOGIN);
      return;
    }
    try {
      _isSending.value = true;
      final msg = await _repository.sendMessage(
        liveMatchId: liveMatchId,
        content: trimmed,
      );
      // optimistic append (Realtime echo가 와도 id로 dedupe).
      _appendIfAbsent(msg);
      composer.clear();
    } catch (e) {
      log('LiveMatchChatController.sendComposerMessage error: $e');
      Get.snackbar('전송 실패', '잠시 후 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      _isSending.value = false;
    }
  }

  Future<void> deleteMessage(ChatMessageResponse msg) async {
    if (msg.userId != currentUserId) return;
    try {
      await _repository.deleteMessage(msg.id);
      _messages.removeWhere((m) => m.id == msg.id);
    } catch (e) {
      log('LiveMatchChatController.deleteMessage error: $e');
      Get.snackbar('삭제 실패', '잠시 후 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ── 신고 · 차단 ─────────────────────────────────────────────

  /// 내가 차단한 사용자 목록을 1회 조회한다.
  ///
  /// 실패해도 예외를 올리지 않는다 — 차단 필터가 없는 채팅이 채팅이 없는 것보다
  /// 낫다. 필터만 미적용되고 신고·차단 액션 자체는 그대로 동작한다.
  Future<void> _loadBlockedUsers() async {
    try {
      final blocked = await _moderationRepository.listBlockedUsers();
      _blockedUserIds
        ..clear()
        ..addAll(
          blocked
              .map((b) => b.blockedId)
              .whereType<String>()
              .where((id) => id.isNotEmpty),
        );
    } catch (e) {
      log('LiveMatchChatController._loadBlockedUsers error: $e');
    }
  }

  List<ChatMessageResponse> _withoutBlocked(
    Iterable<ChatMessageResponse> list,
  ) {
    if (_blockedUserIds.isEmpty) return list.toList();
    return list.where((m) => !_blockedUserIds.contains(m.userId)).toList();
  }

  /// 신고 시트를 연다.
  ///
  /// 채팅 메시지 전용 신고 테이블은 만들지 않는다 — `target_type='user'` 로
  /// **작성자를 신고**하고, 문제가 된 메시지 본문은 `detail` 에 인용해 담는다.
  /// 커뮤니티와 같은 `community_reports` 를 쓰므로 자동 숨김·운영자 푸시
  /// 트리거가 그대로 적용된다.
  ///
  /// 신고에 작성 게이트(이용규칙 동의)를 걸지 않는 것도 커뮤니티와 같다 —
  /// 신고 창구는 누구에게나 열려 있어야 한다. 로그인만 요구한다.
  Future<void> reportMessage(ChatMessageResponse msg) async {
    if (!_requireLogin()) return;
    if (msg.userId == currentUserId) return;

    await CommunityReportSheet.show(
      targetLabel: '사용자',
      onSubmit: (reason, detail) async {
        try {
          await _moderationRepository.createReport(
            CreateCommunityReportParameter.user(
              targetUserId: msg.userId,
              reason: reason,
              detail: _composeReportDetail(msg.content, detail),
            ),
          );
          return true;
        } catch (e) {
          log('LiveMatchChatController.reportMessage error: $e');
          Get.snackbar(
            '신고 실패',
            communityErrorMessage(e),
            snackPosition: SnackPosition.BOTTOM,
          );
          return false;
        }
      },
      // 접수 완료 화면의 "이 사용자 차단하기". 이미 명시적으로 누른 CTA 라
      // 확인 다이얼로그를 겹치지 않는다.
      onBlock: () => blockUser(msg.userId),
    );
  }

  /// 차단 확인 다이얼로그 → 차단.
  Future<void> confirmBlockUser(String userId) async {
    if (!_requireLogin()) return;
    if (userId == currentUserId) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('사용자 차단', style: TextStyle(color: Colors.white)),
        content: const Text(
          '이 사용자의 채팅과 커뮤니티 글이 보이지 않게 됩니다.\n'
          '차단 사실은 상대에게 알려지지 않습니다.',
          style: TextStyle(color: AppColors.subtleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('취소', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('차단', style: TextStyle(color: AppColors.downRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await blockUser(userId);
  }

  /// 차단 실행. 커뮤니티와 같은 `user_blocks` 라 여기서 차단하면 커뮤니티에서도
  /// 즉시 적용된다(그 반대도 마찬가지).
  ///
  /// 커뮤니티는 RLS 가 서버에서 걸러 주므로 다시 불러오기만 하면 되지만,
  /// 채팅은 그렇지 않다. 화면에 이미 떠 있는 메시지를 직접 걷어내고 집합에도
  /// 넣어 이후 도착분까지 막는다.
  Future<void> blockUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _moderationRepository.blockUser(userId);
      _blockedUserIds.add(userId);
      _messages.removeWhere((m) => m.userId == userId);
      Get.snackbar(
        '차단 완료',
        '이 사용자의 메시지가 보이지 않습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('LiveMatchChatController.blockUser error: $e');
      Get.snackbar(
        '차단 실패',
        communityErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  bool _requireLogin() {
    if (currentUserId != null) return true;
    Get.offNamed(Routes.LOGIN);
    return false;
  }

  /// 신고 상세 = 문제 메시지 인용 + 신고자가 쓴 사유.
  ///
  /// 서버 CHECK 가 `char_length(detail) <= 500` 이라 둘을 합치면 넘칠 수 있다.
  /// 신고자가 직접 쓴 문장이 잘리면 맥락이 사라지므로 **인용문 쪽을 먼저**
  /// 줄인다. 길이는 `char_length` 와 맞추기 위해 코드 유닛이 아니라 룬으로 센다.
  static String? _composeReportDetail(String content, String? detail) {
    const label = '[라이브 채팅] ';
    const max = CreateCommunityReportParameter.maxDetailLength;

    final note = detail?.trim() ?? '';
    final quote = content.trim();
    if (quote.isEmpty) return note.isEmpty ? null : _truncate(note, max);

    // 개행 1자를 note 쪽 비용에 포함한다.
    final tail = note.isEmpty ? 0 : note.runes.length + 1;
    final room = max - label.runes.length - tail;
    if (room <= 0) {
      // 사유만으로 이미 한도를 채웠다. 인용을 포기한다.
      return _truncate(note, max);
    }
    final quoted = '$label${_truncate(quote, room)}';
    return note.isEmpty ? quoted : '$quoted\n$note';
  }

  static String _truncate(String value, int max) {
    final runes = value.runes.toList();
    if (runes.length <= max) return value;
    if (max <= 1) return String.fromCharCodes(runes.take(max));
    return '${String.fromCharCodes(runes.take(max - 1))}…';
  }

  // ── Realtime ────────────────────────────────────────────────

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      final uid = currentUserId;
      _channel = client
          .channel(
            'live_match_chat:$liveMatchId',
            opts: RealtimeChannelConfig(key: uid ?? 'anon'),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'live_match_chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'live_match_id',
              value: liveMatchId,
            ),
            callback: _onInsert,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'live_match_chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'live_match_id',
              value: liveMatchId,
            ),
            callback: _onDelete,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'bwf_live_matches',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: liveMatchId,
            ),
            callback: _onScoreUpdate,
          )
          .onPresenceSync((_) => _refreshOnlineCount())
          .onPresenceJoin((_) => _refreshOnlineCount())
          .onPresenceLeave((_) => _refreshOnlineCount())
          .subscribe((status, error) async {
            log('LiveMatchChatController.subscribe status=$status error=$error');
            if (status == RealtimeSubscribeStatus.subscribed && uid != null) {
              try {
                final result = await _channel?.track({
                  'user_id': uid,
                  'online_at': DateTime.now().toIso8601String(),
                });
                log('LiveMatchChatController.track result=$result');
                // sync 이벤트가 누락되는 SDK 동작 대비, track 직후에도 1회 갱신.
                _refreshOnlineCount();
              } catch (e) {
                log('LiveMatchChatController.track error: $e');
              }
            }
          });
    } catch (e) {
      log('LiveMatchChatController._subscribeRealtime error: $e');
    }
  }

  /// presence state는 `List<SinglePresenceState>`이고,
  /// 각 항목의 presences는 같은 key를 가진 연결들이다.
  /// 같은 user_id가 여러 디바이스로 접속했을 때 1명으로 카운트되도록
  /// presence payload의 user_id로 dedupe한다.
  void _refreshOnlineCount() {
    final ch = _channel;
    if (ch == null) return;
    try {
      final state = ch.presenceState();
      final userIds = <String>{};
      var unknownConnections = 0;
      for (final entry in state) {
        for (final p in entry.presences) {
          final payload = p.payload;
          final uid = payload['user_id'];
          if (uid is String && uid.isNotEmpty) {
            userIds.add(uid);
          } else {
            unknownConnections += 1;
          }
        }
      }
      final count = userIds.length + unknownConnections;
      log('LiveMatchChatController.presence state.length=${state.length} '
          'dedupedUsers=${userIds.length} unknown=$unknownConnections '
          'final=$count');
      _onlineCount.value = count;
    } catch (e) {
      log('LiveMatchChatController._refreshOnlineCount error: $e');
    }
  }

  void _unsubscribeRealtime() {
    final ch = _channel;
    if (ch == null) return;
    try {
      Supabase.instance.client.removeChannel(ch);
    } catch (e) {
      log('LiveMatchChatController._unsubscribeRealtime error: $e');
    }
    _channel = null;
  }

  Future<void> _onInsert(PostgresChangePayload payload) async {
    try {
      final id = payload.newRecord['id'] as String?;
      if (id == null) return;
      // 이미 본인 메시지로 optimistic append 된 경우 skip.
      if (_messages.any((m) => m.id == id)) return;
      // 작성자 프로필을 함께 가져오기 위해 repository로 재조회.
      final msg = await _repository.fetchById(id);
      if (msg == null) return;
      await _blockedReady;
      if (_blockedUserIds.contains(msg.userId)) return;
      _appendIfAbsent(msg);
    } catch (e) {
      log('LiveMatchChatController._onInsert error: $e');
    }
  }

  void _onScoreUpdate(PostgresChangePayload payload) {
    final score = _scoreToString(payload.newRecord['score']);
    if (score != null && score.isNotEmpty) {
      _liveScore.value = score;
    }
  }

  /// score 컬럼은 문자열("21-18, 15-12"), 문자열 배열(["21-18","15-12"]),
  /// 맵 배열([{"set":1,"home":22,"away":20}, ...]) 형태로 내려올 수 있어
  /// "home-away, home-away" 문자열로 정규화한다.
  static String? _scoreToString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.trim();
    if (raw is List) {
      final parts = <String>[];
      for (final e in raw) {
        if (e is Map) {
          final home = e['home'] ?? e['team1'];
          final away = e['away'] ?? e['team2'];
          if (home != null && away != null) parts.add('$home-$away');
        } else {
          final s = e?.toString().trim();
          if (s != null && s.isNotEmpty) parts.add(s);
        }
      }
      return parts.join(', ').trim();
    }
    return raw.toString().trim();
  }

  void _onDelete(PostgresChangePayload payload) {
    final id = payload.oldRecord['id'] as String?;
    if (id == null) return;
    _messages.removeWhere((m) => m.id == id);
  }

  void _appendIfAbsent(ChatMessageResponse msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    _messages.add(msg);
  }
}
