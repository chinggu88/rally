import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:rally/app/modules/news/controllers/news_controller.dart';

import '../../match/controllers/match_controller.dart';
import '../../player/controllers/player_controller.dart';

/// 앱 셸 컨트롤러.
///
/// 바텀 네비게이션의 현재 탭 인덱스를 관리하고,
/// 앱 라이프사이클(`AppLifecycleState`) 변경을 관찰해 [lifecycleState]로 노출한다.
/// 다른 컨트롤러가 필요할 때 `ever(AppController.to.lifecycleState, ...)`로 구독한다.
class AppController extends GetxController with WidgetsBindingObserver {
  static AppController get to => Get.find();

  /// 경기 탭 인덱스 (BottomNavigationBar 순서: 뉴스0 / 경기1 / 선수2 / 내정보3)
  static const int matchTabIndex = 1;

  /// 선수 탭 인덱스
  static const int playerTabIndex = 2;

  final _currentIndex = 0.obs;

  int get currentIndex => _currentIndex.value;
  set currentIndex(int value) => _currentIndex.value = value;

  void changeTab(int index) {
    currentIndex = index;

    // 경기 탭 진입 시 LIVE/진행중/임박 대회 카드로 자동 스크롤.
    if (index == matchTabIndex && Get.isRegistered<MatchController>()) {
      MatchController.to.autoScrollToFeaturedTournament();
    }

    // 선수 탭 진입 시 첫 페이지를 다시 로드(로딩 인디케이터 노출).
    if (index == playerTabIndex && Get.isRegistered<PlayerController>()) {
      PlayerController.to.reloadFromTab();
    }
  }

  /// 현재 앱 라이프사이클 상태. 초기값은 resumed.
  final Rx<AppLifecycleState> lifecycleState = AppLifecycleState.resumed.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    lifecycleState.value = state;
    log('AppController lifecycle: ${state.name}', name: 'AppController');
    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 돌아왔을 때 필요한 작업 수행
        NewsController.to.fetchActiveTournaments();
        NewsController.to.fetchLiveMatches();
        NewsController.to.subscribeRealtime();
        break;
      case AppLifecycleState.inactive:
        // 앱이 비활성화 상태가 되었을 때 필요한 작업 수행
        break;
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 갔을 때 필요한 작업 수행
        NewsController.to.unsubscribeRealtime();
        break;
      case AppLifecycleState.detached:
        // 앱이 완전히 종료되었을 때 필요한 작업 수행
        break;
      case AppLifecycleState.hidden:
        // 앱이 숨겨졌을 때 필요한 작업 수행 (예: 화면이 꺼졌을 때)
        NewsController.to.unsubscribeRealtime();
        break;
    }
  }
}
