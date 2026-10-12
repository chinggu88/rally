import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/data/models/favorite_match_response.dart';
import '../app/data/models/today_match_response.dart';
import '../app/data/repositories/favorite_match_repository.dart';
import 'live_activity_service.dart';

/// 관심 경기 + 홈스크린 위젯 갱신을 담당하는 전역 서비스.
///
/// `HomeController`가 아니라 여기 있는 이유: 위젯 갱신은 홈 탭 생명주기와
/// 무관하게(로그아웃/백그라운드 진입 포함) 살아있어야 한다.
///
/// 위젯은 항상 **1경기만** 표시하므로 [_pickForWidget]이 우선순위를 정한다.
class FavoriteMatchService extends GetxService {
  static FavoriteMatchService get to => Get.find();

  /// iOS App Group ID. Runner/Extension entitlements와 **반드시 동일**해야 한다.
  /// (오타 시 에러 없이 조용히 빈 위젯이 된다.)
  static const String appGroupId = 'group.com.iksun.rallys';

  /// 네이티브가 읽는 단일 키. 키를 흩으면 부분 갱신으로 불일치가 생긴다.
  static const String _widgetDataKey = 'rally_match';

  static const String _androidWidgetName = 'RallyWidgetProvider';
  static const String _iOSWidgetName = 'RallyWidget';

  final FavoriteMatchRepository _repository = FavoriteMatchRepository();

  /// 관심 경기 match_code 집합 — 카드 토글 상태의 단일 진실 공급원.
  final RxSet<String> favoriteCodes = <String>{}.obs;

  /// 관심 경기 스냅샷 (match_code → 스냅샷). 위젯 렌더 소스.
  final Map<String, FavoriteMatchResponse> _snapshots =
      <String, FavoriteMatchResponse>{};

  /// 토글 처리 중인 match_code (중복 탭 방지).
  final RxSet<String> _toggling = <String>{}.obs;

  /// DB 스냅샷 쓰기 디바운스 — 라이브 중 포인트마다 쓰지 않기 위함.
  Timer? _snapshotDebounce;
  final Set<String> _pendingSnapshotCodes = <String>{};

  @override
  void onInit() {
    super.onInit();
    HomeWidget.setAppGroupId(appGroupId);
  }

  @override
  void onClose() {
    _snapshotDebounce?.cancel();
    super.onClose();
  }

  /// 서버에서 관심 경기를 로드하고 위젯을 갱신한다. (앱 시작 / 로그인 후)
  Future<void> load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await clear();
      return;
    }
    try {
      final list = await _repository.listFavorites();
      _snapshots
        ..clear()
        ..addEntries(list.map((e) => MapEntry(e.matchCode, e)));
      favoriteCodes.assignAll(_snapshots.keys);
    } catch (e) {
      log('FavoriteMatchService.load error: $e');
    }
    await pushToWidget();
  }

  bool isFavorite(String? matchCode) =>
      matchCode != null && favoriteCodes.contains(matchCode);

  /// 관심 경기 추가/삭제 토글. 비로그인 시 안내만 표시한다.
  Future<void> toggle(TodayMatchResponse match) async {
    final code = match.matchCode;
    if (code == null || code.isEmpty) return;

    if (Supabase.instance.client.auth.currentUser == null) {
      Get.snackbar(
        '로그인이 필요해요',
        '관심 경기는 로그인 후 이용할 수 있습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_toggling.contains(code)) return;
    _toggling.add(code);

    final wasFavorite = favoriteCodes.contains(code);
    final prevSnapshot = _snapshots[code];

    // 낙관적 반영
    if (wasFavorite) {
      favoriteCodes.remove(code);
      _snapshots.remove(code);
    } else {
      favoriteCodes.add(code);
      _snapshots[code] = _toSnapshot(match);
    }
    await pushToWidget();

    try {
      if (wasFavorite) {
        await _repository.removeFavorite(code);
      } else {
        final s = _snapshots[code]!;
        await _repository.addFavorite(
          matchCode: s.matchCode,
          matchId: s.matchId,
          tournamentName: s.tournamentName,
          roundName: s.roundName,
          eventName: s.eventName,
          courtName: s.courtName,
          team1Name: s.team1Name,
          team1Country: s.team1Country,
          team2Name: s.team2Name,
          team2Country: s.team2Country,
          score: s.score,
          matchStatus: s.matchStatus,
          matchTimeKst: s.matchTimeKst,
          isLive: s.isLive,
        );
      }
    } catch (e) {
      // 롤백
      if (wasFavorite) {
        favoriteCodes.add(code);
        if (prevSnapshot != null) _snapshots[code] = prevSnapshot;
      } else {
        favoriteCodes.remove(code);
        _snapshots.remove(code);
      }
      await pushToWidget();
      log('FavoriteMatchService.toggle error: $e');
      Get.snackbar(
        '처리 실패',
        '잠시 후 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _toggling.remove(code);
    }
  }

  /// 오늘 경기 재조회 결과로 스냅샷을 최신화한다.
  ///
  /// `get-today-matches`는 라이브 중인 경기를 제외하므로, 여기 없는 관심 경기는
  /// 지우지 않고 기존 스냅샷을 유지한다(라이브 전환 중일 수 있다).
  Future<void> syncFromToday(List<TodayMatchResponse> matches) async {
    if (favoriteCodes.isEmpty) return;
    var changed = false;
    for (final m in matches) {
      final code = m.matchCode;
      if (code == null || !favoriteCodes.contains(code)) continue;
      _snapshots[code] = _toSnapshot(m);
      changed = true;
    }
    if (changed) await pushToWidget();
  }

  /// `bwf_live_matches` Realtime row를 관심 경기 스냅샷에 반영한다.
  ///
  /// **반드시 `match_code`로 매칭한다.** `bwf_live_matches.id`는
  /// `bwf_matches.id`와 다른 테이블의 PK라 id 비교는 항상 틀린다.
  void applyLiveScore(Map<String, dynamic> row) {
    final code = row['match_code'];
    if (code is! String || !favoriteCodes.contains(code)) return;

    final existing = _snapshots[code];
    if (existing == null) return;

    final score = row['score']?.toString();
    final status = row['match_status']?.toString();
    final live = _isLiveRow(row);

    if ((existing.score ?? '') == (score ?? '') &&
        existing.isLive == live &&
        (existing.matchStatus ?? '') == (status ?? '')) {
      return; // 변화 없음 — 위젯 갱신 예산 낭비 방지
    }

    _snapshots[code] = existing.copyWith(
      score: score,
      matchStatus: status,
      isLive: live,
    );

    pushToWidget(); // 위젯은 즉시
    _queueSnapshotWrite(code); // DB는 디바운스
  }

  /// 로그아웃 시 상태와 위젯을 비운다.
  Future<void> clear() async {
    favoriteCodes.clear();
    _snapshots.clear();
    _pendingSnapshotCodes.clear();
    _snapshotDebounce?.cancel();
    if (Get.isRegistered<LiveActivityService>()) {
      await LiveActivityService.to.end();
    }
    await pushToWidget();
  }

  /// 우선순위 경기 1건을 골라 위젯과 Live Activity에 반영한다.
  Future<void> pushToWidget() async {
    final picked = _pickForWidget();

    try {
      await HomeWidget.saveWidgetData<String>(
        _widgetDataKey,
        picked == null ? null : jsonEncode(picked.toWidgetJson()),
      );
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      log('FavoriteMatchService.pushToWidget error: $e');
    }

    await _syncLiveActivity(picked);
  }

  /// Live Activity는 "진행 중인 경기"에만 띄운다.
  ///
  /// 끝난 경기나 관심 경기가 없는 상태에서는 종료한다. 홈 위젯과 달리
  /// 잠금화면을 계속 점유하면 안 되기 때문이다.
  Future<void> _syncLiveActivity(FavoriteMatchResponse? picked) async {
    if (!Get.isRegistered<LiveActivityService>()) return;
    final service = LiveActivityService.to;

    if (picked == null || picked.isFinished) {
      if (service.activeMatchCode != null) await service.end();
      return;
    }

    if (service.activeMatchCode == picked.matchCode) {
      await service.update(picked);
    } else {
      await service.start(picked);
    }
  }

  // ── 내부 ───────────────────────────────────────────────────

  /// 위젯에 표시할 1경기 선정: 라이브 > 아직 안 끝난 것 > 끝난 것.
  ///
  /// 같은 그룹 안에서는 최근 갱신 순(=`listFavorites` 정렬)을 따른다.
  FavoriteMatchResponse? _pickForWidget() {
    if (_snapshots.isEmpty) return null;
    final all = _snapshots.values.toList();

    for (final m in all) {
      if (m.isLive) return m;
    }
    for (final m in all) {
      if (!m.isFinished) return m;
    }
    return all.first;
  }

  FavoriteMatchResponse _toSnapshot(TodayMatchResponse m) {
    return FavoriteMatchResponse(
      matchCode: m.matchCode!,
      matchId: m.id,
      tournamentName: m.tournamentName,
      roundName: m.roundName,
      eventName: m.eventName,
      courtName: m.courtName,
      team1Name: m.team1Display,
      team1Country: m.team1Country,
      team2Name: m.team2Display,
      team2Country: m.team2Country,
      score: m.score,
      matchStatus: m.matchStatus,
      matchTimeKst: m.displayKoreanTime,
      isLive: false, // today 목록은 라이브를 제외하므로 항상 false
    );
  }

  /// `bwf_live_matches` row가 아직 라이브인지 판정.
  bool _isLiveRow(Map<String, dynamic> row) {
    final ts = row['tournament_status']?.toString().toLowerCase().trim();
    return ts == 'live';
  }

  /// DB 스냅샷 쓰기를 5초 디바운스로 모은다.
  void _queueSnapshotWrite(String code) {
    _pendingSnapshotCodes.add(code);
    _snapshotDebounce?.cancel();
    _snapshotDebounce = Timer(const Duration(seconds: 5), _flushSnapshots);
  }

  /// 대기 중인 스냅샷을 DB에 반영한다. (백그라운드 진입 시에도 호출)
  Future<void> flushSnapshots() async {
    _snapshotDebounce?.cancel();
    await _flushSnapshots();
  }

  Future<void> _flushSnapshots() async {
    if (_pendingSnapshotCodes.isEmpty) return;
    final codes = _pendingSnapshotCodes.toList();
    _pendingSnapshotCodes.clear();
    for (final code in codes) {
      final s = _snapshots[code];
      if (s == null) continue;
      await _repository.updateSnapshot(
        matchCode: code,
        score: s.score,
        matchStatus: s.matchStatus,
        isLive: s.isLive,
      );
    }
  }
}
