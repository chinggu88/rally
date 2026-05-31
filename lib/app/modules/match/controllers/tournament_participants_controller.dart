import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/tournament_participant_response.dart';
import '../../../data/repositories/tournament_repository.dart';

/// 대회 참가 선수 화면 컨트롤러.
///
/// 대회 상세 화면([TournamentDetailView])의 "대진표 보기" CTA를 통해
/// 진입한다. arguments로 `tournament_id`(필수)와 `tournament_name`(AppBar
/// 타이틀용, 선택)을 받는다.
///
/// Supabase Edge Function `get-tournament-participants`를 호출해 종목별
/// (MS/WS/MD/WD/XD) 참가자를 조회한다. 종목 칩 전환 시 race condition을
/// 피하기 위해 `_inflightToken` 카운터를 사용한다.
class TournamentParticipantsController extends GetxController {
  /// arguments 키 — `bwf_tournaments.tournament_id` (양수 정수)
  static const String argTournamentId = 'tournament_id';

  /// arguments 키 — AppBar 타이틀에 사용할 대회명
  static const String argTournamentName = 'tournament_name';

  /// 지원하는 종목 코드 목록 (BWF 5종)
  static const List<String> events = <String>[
    'MS', // Men's Singles
    'WS', // Women's Singles
    'MD', // Men's Doubles
    'WD', // Women's Doubles
    'XD', // Mixed Doubles
  ];

  /// 종목 코드 → 한국어 라벨
  static const Map<String, String> _eventLabelsKo = <String, String>{
    'MS': '남자 단식',
    'WS': '여자 단식',
    'MD': '남자 복식',
    'WD': '여자 복식',
    'XD': '혼합 복식',
  };

  /// 종목 코드 → 영문 라벨
  static const Map<String, String> _eventLabelsEn = <String, String>{
    'MS': "Men's Singles",
    'WS': "Women's Singles",
    'MD': "Men's Doubles",
    'WD': "Women's Doubles",
    'XD': 'Mixed Doubles',
  };

  /// 종목 코드 → 한국어 라벨 조회 (없으면 코드 그대로)
  static String labelKoOf(String code) => _eventLabelsKo[code] ?? code;

  /// 종목 코드 → 영문 라벨 조회 (없으면 코드 그대로)
  static String labelEnOf(String code) => _eventLabelsEn[code] ?? code;

  final TournamentRepository _tournamentRepository =
      Get.find<TournamentRepository>();

  /// 조회 대상 tournament_id (null이면 조회 불가 → empty 상태로 표시)
  int? _tournamentId;
  int? get tournamentId => _tournamentId;

  /// AppBar 타이틀에 표시할 대회명 (없으면 "참가 선수" 폴백)
  String? _tournamentName;
  String? get tournamentName => _tournamentName;

  /// 현재 선택된 종목 (기본값: `'MS'`)
  final _selectedEvent = 'MS'.obs;
  String get selectedEvent => _selectedEvent.value;
  set selectedEvent(String val) => _selectedEvent.value = val;

  /// API 요청 중 로딩 상태 여부
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => _isLoading.value = val;

  /// 에러 메시지 (null이면 정상 상태로 간주)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => _errorMessage.value = val;

  /// 참가자 목록 (서버 정렬: seed ASC nulls last → player1_name ASC)
  final _participants = <TournamentParticipantResponse>[].obs;
  List<TournamentParticipantResponse> get participants => _participants;

  /// 진행 중인 inflight 요청 토큰 (race condition 방지)
  int _inflightToken = 0;

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    fetchParticipants();
  }

  /// 네비게이션 arguments 파싱 — Map / int 모두 허용.
  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      _tournamentId = _asInt(args[argTournamentId]);
      final name = args[argTournamentName];
      if (name is String && name.trim().isNotEmpty) {
        _tournamentName = name.trim();
      }
    } else if (args is int) {
      _tournamentId = args;
    }
  }

  /// 참가자 목록을 조회한다.
  ///
  /// [event] 조회할 종목. null이면 현재 `selectedEvent`를 사용한다.
  Future<void> fetchParticipants({String? event}) async {
    final id = _tournamentId;
    final targetEvent = event ?? selectedEvent;

    if (id == null || id <= 0) {
      // 식별자가 없으면 조회 불가 — 빈 목록으로 표시
      _participants.clear();
      isLoading = false;
      errorMessage = null;
      return;
    }

    final token = ++_inflightToken;

    try {
      isLoading = true;
      errorMessage = null;

      final response = await _tournamentRepository.getTournamentParticipants(
        tournamentId: id,
        eventName: targetEvent,
      );

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _inflightToken) return;

      _participants.assignAll(
        response.participants ?? const <TournamentParticipantResponse>[],
      );

      final returnedEvent = response.eventName;
      if (returnedEvent != null && returnedEvent.isNotEmpty) {
        selectedEvent = returnedEvent;
      } else {
        selectedEvent = targetEvent;
      }
    } catch (e) {
      if (token != _inflightToken) return;
      log('TournamentParticipantsController.fetchParticipants error: $e');
      errorMessage = '참가 선수 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      _participants.clear();
    } finally {
      if (token == _inflightToken) {
        isLoading = false;
      }
    }
  }

  /// Pull-to-refresh / 재시도 버튼용 — 현재 `selectedEvent`로 재호출한다.
  Future<void> refreshParticipants() async {
    await fetchParticipants(event: selectedEvent);
  }

  /// 종목을 변경하고 목록을 다시 불러온다.
  ///
  /// [event] 새로 선택된 종목. 동일 종목 재선택 시 no-op.
  /// 5개 허용 종목(MS/WS/MD/WD/XD)이 아니면 무시한다.
  Future<void> changeEvent(String event) async {
    if (event == selectedEvent) return;
    if (!events.contains(event)) {
      log('TournamentParticipantsController.changeEvent: '
          'unsupported event=$event');
      return;
    }
    selectedEvent = event;
    await fetchParticipants(event: event);
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
