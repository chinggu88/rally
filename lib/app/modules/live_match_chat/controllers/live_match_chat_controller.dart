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
      _channel = client
          .channel('live_match_chat:$liveMatchId')
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
          .subscribe();
    } catch (e) {
      log('LiveMatchChatController._subscribeRealtime error: $e');
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
