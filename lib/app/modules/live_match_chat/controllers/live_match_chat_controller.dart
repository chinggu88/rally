import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/chat_message_response.dart';
import '../../../data/repositories/chat_message_repository.dart';
import '../../../routes/app_routes.dart';

/// 라이브 매치 채팅방 컨트롤러.
///
/// 진입 시 비로그인이면 즉시 로그인 화면으로 리다이렉트한다.
/// 메시지 로드 → Realtime 구독 → 사용자 입력 INSERT 순으로 동작.
class LiveMatchChatController extends GetxController {
  static const int pageSize = 50;
  static const int maxContentLen = 500;

  final ChatMessageRepository _repository = Get.find<ChatMessageRepository>();

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

  final composer = TextEditingController();
  String? get currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  RealtimeChannel? _channel;

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
      // DESC로 받은 것을 ASC로 뒤집어 저장 (오래된 → 최신)
      _messages.assignAll(list.reversed.toList());
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
      // 새로 받은 페이지는 DESC. 앞쪽(오래된 영역)에 ASC로 prepend.
      _messages.insertAll(0, list.reversed.toList());
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
