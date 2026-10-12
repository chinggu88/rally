import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:rally/app/data/repositories/auth_repository.dart';
import 'package:rally/app/modules/home/controllers/home_controller.dart';
import 'package:rally/app/routes/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/favorite_match_service.dart';
import '../../community/controllers/community_controller.dart';
import '../../match/controllers/match_controller.dart';
import '../../player/controllers/player_controller.dart';

/// 앱 셸 컨트롤러.
///
/// 바텀 네비게이션의 현재 탭 인덱스를 관리하고,
/// 앱 라이프사이클(`AppLifecycleState`) 변경을 관찰해 [lifecycleState]로 노출한다.
/// 다른 컨트롤러가 필요할 때 `ever(AppController.to.lifecycleState, ...)`로 구독한다.
class AppController extends GetxController with WidgetsBindingObserver {
  static AppController get to => Get.find();

  /// 경기 탭 인덱스
  /// (BottomNavigationBar 순서: 홈0 / 경기1 / 선수2 / 커뮤니티3 / 내정보4)
  static const int matchTabIndex = 1;

  /// 선수 탭 인덱스
  static const int playerTabIndex = 2;

  /// 커뮤니티 탭 인덱스 — 내정보 앞에 넣어 경기/선수 인덱스를 유지한다.
  static const int communityTabIndex = 3;

  final _currentIndex = 0.obs;

  int get currentIndex => _currentIndex.value;
  set currentIndex(int value) => _currentIndex.value = value;

  final AuthRepository _authRepository = Get.find<AuthRepository>();
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri?>? _widgetSub;

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

    // 커뮤니티 탭은 최초 진입 시에만 로드한다. onInit에서 부르면 IndexedStack
    // 때문에 콜드 스타트마다 쿼리가 붙고, 매번 리셋하면 스크롤·목록이 날아간다.
    if (index == communityTabIndex && Get.isRegistered<CommunityController>()) {
      CommunityController.to.loadIfNeeded();
    }
  }

  /// 현재 앱 라이프사이클 상태. 초기값은 resumed.
  final Rx<AppLifecycleState> lifecycleState = AppLifecycleState.resumed.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // 이메일/소셜 모두 동일하게 SIGNED_IN 이벤트로 처리되도록 단일 진실 공급원 구독.
    _authSub = _authRepository.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        FavoriteMatchService.to.load();
        Get.offAllNamed(Routes.APP);
      } else if (state.event == AuthChangeEvent.signedOut) {
        FavoriteMatchService.to.clear();
      }
    });

    // 관심 경기 초기 로드 + 홈스크린 위젯 갱신.
    FavoriteMatchService.to.load();
    _listenWidgetLaunch();
  }

  /// 홈스크린 위젯 탭으로 앱이 열렸을 때 홈 탭으로 이동한다.
  ///
  /// 콜드 스타트(`initiallyLaunchedFromHomeWidget`)와 웜 스타트
  /// (`widgetClicked`) 경로가 별개라 **둘 다** 필요하다.
  void _listenWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetLaunch);
    _widgetSub = HomeWidget.widgetClicked.listen(_onWidgetLaunch);
  }

  void _onWidgetLaunch(Uri? uri) {
    if (uri == null) return;
    currentIndex = 0; // 홈 탭
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _widgetSub?.cancel();
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
        HomeController.to.fetchActiveTournaments();
        HomeController.to.fetchLiveMatches();
        HomeController.to.subscribeRealtime();
        break;
      case AppLifecycleState.inactive:
        // 앱이 비활성화 상태가 되었을 때 필요한 작업 수행
        break;
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 갔을 때 필요한 작업 수행
        HomeController.to.unsubscribeRealtime();
        // 디바운스 대기 중인 관심 경기 스냅샷을 DB에 반영한다.
        FavoriteMatchService.to.flushSnapshots();
        break;
      case AppLifecycleState.detached:
        // 앱이 완전히 종료되었을 때 필요한 작업 수행
        break;
      case AppLifecycleState.hidden:
        // 앱이 숨겨졌을 때 필요한 작업 수행 (예: 화면이 꺼졌을 때)
        HomeController.to.unsubscribeRealtime();
        break;
    }
  }
}
