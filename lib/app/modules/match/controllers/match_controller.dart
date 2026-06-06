import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/tournament_response.dart';
import '../../../data/repositories/tournament_repository.dart';
import '../../../routes/app_routes.dart';
import 'tournament_detail_controller.dart';

/// 경기(국제 대회) 화면 컨트롤러.
///
/// Supabase Edge Function `get-tournaments` 를 호출해 연도별 BWF 국제 대회 목록을 조회한다.
/// 진입 시 자동으로 현재 연도 데이터를 로드하고, 연도 변경/새로고침/외부 상세 페이지 오픈을 지원한다.
class MatchController extends GetxController {
  /// Singleton accessor
  static MatchController get to => Get.find();

  /// 대회 목록 조회 레포지토리 (Supabase Edge Function 호출 담당)
  final TournamentRepository _tournamentRepository = TournamentRepository();

  /// API 요청 중 로딩 상태 여부 (스피너 표시 등에 사용)
  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => _isLoading.value = val;

  /// 화면에 표시할 BWF 국제 대회 목록 (start_date 오름차순으로 정렬됨)
  final _tournaments = <TournamentResponse>[].obs;
  List<TournamentResponse> get tournaments => _tournaments;
  set tournaments(List<TournamentResponse> val) =>
      _tournaments.assignAll(val);

  /// 에러 메시지 (null/빈 문자열이면 정상 상태로 간주)
  final _errorMessage = RxnString();
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => _errorMessage.value = val;

  /// 현재 선택된 조회 연도 (기본값: 디바이스 현재 연도)
  final _selectedYear = DateTime.now().year.obs;
  int get selectedYear => _selectedYear.value;
  set selectedYear(int val) => _selectedYear.value = val;

  /// 상세 진입 중복 가드 (탭 더블탭 방지)
  bool _isOpeningDetail = false;

  /// 자동 스크롤 대상 대회 ID. 값이 설정되면 View가 해당 카드로 스크롤한 뒤
  /// `clearScrollTarget()`으로 다시 비운다. (null = 스크롤 요청 없음)
  final scrollTargetId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    fetchTournaments();
  }

  /// 대회 목록을 조회한다.
  ///
  /// [year] 조회할 연도. null이면 현재 `selectedYear`를 사용한다.
  Future<void> fetchTournaments({int? year}) async {
    final targetYear = year ?? selectedYear;

    try {
      isLoading = true;
      errorMessage = null;

      final response = await _tournamentRepository.getTournaments(
        year: targetYear,
      );

      final fetched =
          (response.tournaments ?? const <TournamentResponse>[]).toList();

      // start_date 오름차순 정렬 (null은 가장 뒤로)
      fetched.sort((a, b) {
        final ad = a.startDate;
        final bd = b.startDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

      tournaments = fetched;
      if (response.year != null) {
        selectedYear = response.year!;
      } else {
        selectedYear = targetYear;
      }
    } catch (e) {
      log('MatchController.fetchTournaments error: $e');
      errorMessage = '대회 목록을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      tournaments = const <TournamentResponse>[];
    } finally {
      isLoading = false;
    }
  }

  /// Pull-to-refresh / 재시도 버튼용 — 현재 `selectedYear`로 재호출한다.
  Future<void> refreshTournaments() async {
    await fetchTournaments(year: selectedYear);
  }

  /// 조회 연도를 변경하고 목록을 다시 불러온다.
  ///
  /// [year] 새로 선택된 연도 (2000–2100 권장)
  Future<void> changeYear(int year) async {
    if (year == selectedYear) return;
    selectedYear = year;
    await fetchTournaments(year: year);
  }

  /// 다음 연도로 이동한다.
  Future<void> goNextYear() => changeYear(selectedYear + 1);

  /// 이전 연도로 이동한다.
  Future<void> goPreviousYear() => changeYear(selectedYear - 1);

  /// 경기 탭 진입 시 LIVE/진행중/임박 대회 카드로 자동 스크롤한다.
  ///
  /// 우선순위: ① LIVE 경기 → ② 오늘 진행 중인 대회 → ③ 가장 가까운 개최예정 대회.
  /// 대상 대회 ID를 [scrollTargetId]에 실으면 View가 해당 카드로 스크롤한다.
  Future<void> autoScrollToFeaturedTournament() async {
    // 아직 로딩 중이거나 비어 있으면 데이터 로드를 기다린다.
    if (isLoading || tournaments.isEmpty) {
      await fetchTournaments();
    }

    final target = _pickFeaturedTournament();
    final id = target?.tournamentId;
    if (id != null) {
      // 동일 ID를 연속 요청해도 트리거되도록 먼저 비운 뒤 설정한다.
      scrollTargetId.value = null;
      scrollTargetId.value = id;
    }
  }

  /// 자동 스크롤 처리가 끝난 뒤 View에서 호출해 대상을 비운다.
  void clearScrollTarget() => scrollTargetId.value = null;

  /// 자동 이동 대상 대회를 우선순위에 따라 선택한다. 없으면 null.
  TournamentResponse? _pickFeaturedTournament() {
    if (tournaments.isEmpty) return null;

    // ① 현재 LIVE 중인 대회
    for (final t in tournaments) {
      if (t.isLiveNow) return t;
    }

    // ② 오늘 진행 중인 대회
    for (final t in tournaments) {
      if (t.isOngoing) return t;
    }

    // ③ 오늘 이후 시작하는 대회 중 가장 가까운(시작일이 빠른) 대회
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    TournamentResponse? nearest;
    DateTime? nearestStart;
    for (final t in tournaments) {
      final start = t.startDateTime;
      if (start == null) continue;
      final startDay = DateTime(start.year, start.month, start.day);
      if (startDay.isBefore(today)) continue;
      if (nearestStart == null || startDay.isBefore(nearestStart)) {
        nearest = t;
        nearestStart = startDay;
      }
    }
    return nearest;
  }

  /// 대회 상세 화면(인앱)으로 이동한다.
  ///
  /// [t] 탭된 대회 항목. `tournament_id`로 상세를 조회하며, 리스트에서 받은
  /// 항목 자체를 폴백 컨텍스트로 함께 넘겨 상세 로드 전에도 화면을 그린다.
  Future<void> openTournamentDetail(TournamentResponse t) async {
    if (_isOpeningDetail) return;

    final id = t.tournamentId;
    if (id == null) {
      log('MatchController.openTournamentDetail: tournamentId is null');
      return;
    }

    try {
      _isOpeningDetail = true;
      await Get.toNamed<void>(
        Routes.MATCH_DETAIL,
        arguments: <String, dynamic>{
          TournamentDetailController.argTournamentId: id,
          TournamentDetailController.argFallback: t,
        },
      );
    } catch (e) {
      log('MatchController.openTournamentDetail error: $e');
    } finally {
      _isOpeningDetail = false;
    }
  }
}
