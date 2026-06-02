import 'dart:developer';

import 'package:get/get.dart';

import '../../../data/models/live_match_response.dart';
import '../../../data/repositories/live_match_repository.dart';

/// 홈(뉴스) 화면 컨트롤러.
///
/// 현재 홈 탭은 뉴스 placeholder + 상단 고정 라이브 매치 영역을 제공한다.
/// 라이브 매치는 Supabase Edge Function `get-live-matches`에서 받아온다.
///
/// 동시 호출(예: 빠른 pull-to-refresh)에서의 race condition을 방지하기 위해
/// `_inflightToken` 카운터를 사용한다.
class NewsController extends GetxController {
  static NewsController get to => Get.find();

  final LiveMatchRepository _liveMatchRepository =
      Get.find<LiveMatchRepository>();

  /// 라이브 매치 목록 (start_date ASC → id ASC)
  final _liveMatches = <LiveMatchResponse>[].obs;
  List<LiveMatchResponse> get liveMatches => _liveMatches;

  /// 라이브 매치 로딩 중 여부
  final _isLiveLoading = false.obs;
  bool get isLiveLoading => _isLiveLoading.value;
  set isLiveLoading(bool v) => _isLiveLoading.value = v;

  /// 라이브 매치 에러 메시지 (null이면 정상)
  final _liveError = RxnString();
  String? get liveError => _liveError.value;
  set liveError(String? v) => _liveError.value = v;

  /// 진행 중인 inflight 요청 토큰 (race condition 방지)
  int _inflightToken = 0;

  @override
  void onInit() {
    super.onInit();
    fetchLiveMatches();
  }

  /// 라이브 매치 목록을 조회한다.
  Future<void> fetchLiveMatches() async {
    final token = ++_inflightToken;

    try {
      isLiveLoading = true;
      liveError = null;

      final response = await _liveMatchRepository.getLiveMatches();

      // race condition 가드: 더 새로운 요청이 발생했으면 결과 무시
      if (token != _inflightToken) return;

      _liveMatches.assignAll(
        response.matches ?? const <LiveMatchResponse>[],
      );
    } catch (e) {
      if (token != _inflightToken) return;
      log('NewsController.fetchLiveMatches error: $e');
      liveError = '라이브 매치 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
      _liveMatches.clear();
    } finally {
      if (token == _inflightToken) {
        isLiveLoading = false;
      }
    }
  }

  /// Pull-to-refresh / 재시도 버튼용 — 라이브 매치 재호출.
  Future<void> refreshLiveMatches() async {
    await fetchLiveMatches();
  }
}
