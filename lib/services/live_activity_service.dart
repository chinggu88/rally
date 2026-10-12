import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/data/models/favorite_match_response.dart';
import '../app/data/repositories/live_activity_token_repository.dart';

/// Live Activity(잠금화면 + 다이나믹 아일랜드) 제어 서비스.
///
/// iOS 16.1+ 전용이며 그 외 플랫폼에서는 모든 메서드가 조용히 no-op이다.
/// 다이나믹 아일랜드는 iPhone 14 Pro 이상에서만 보이고, 그 외 기기는
/// 잠금화면 카드만 표시된다(같은 Activity라 코드는 동일하다).
///
/// 앱이 백그라운드/종료 상태일 때의 스코어 갱신은 서버가 APNs로 푸시한다.
/// 그래서 ActivityKit이 발급한 push token을 서버에 저장해야 한다.
class LiveActivityService extends GetxService {
  static LiveActivityService get to => Get.find();

  static const MethodChannel _channel = MethodChannel('rally/live_activity');

  final LiveActivityTokenRepository _tokenRepository =
      LiveActivityTokenRepository();

  /// 현재 Activity가 떠 있는 match_code (동시에 1개만 운영한다).
  String? _activeMatchCode;
  String? get activeMatchCode => _activeMatchCode;

  @override
  void onInit() {
    super.onInit();
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  bool get _isAvailable => Platform.isIOS;

  /// 기기/설정에서 Live Activity가 허용되어 있는지.
  Future<bool> isSupported() async {
    if (!_isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      log('LiveActivityService.isSupported error: ${e.message}');
      return false;
    }
  }

  /// 관심 경기에 대한 Live Activity를 시작한다.
  ///
  /// 이미 다른 경기의 Activity가 떠 있으면 먼저 종료한다(동시 1개 정책).
  Future<void> start(FavoriteMatchResponse match) async {
    if (!_isAvailable) return;
    if (!await isSupported()) return;

    if (_activeMatchCode != null && _activeMatchCode != match.matchCode) {
      await end(_activeMatchCode);
    }

    try {
      await _channel.invokeMethod<void>('start', _payload(match));
      _activeMatchCode = match.matchCode;
    } on PlatformException catch (e) {
      log('LiveActivityService.start error: ${e.code} ${e.message}');
    }
  }

  /// 포그라운드에서 받은 스코어를 즉시 반영한다(푸시 왕복 없이).
  Future<void> update(FavoriteMatchResponse match) async {
    if (!_isAvailable) return;
    if (_activeMatchCode != match.matchCode) return;

    try {
      await _channel.invokeMethod<void>('update', _payload(match));
    } on PlatformException catch (e) {
      log('LiveActivityService.update error: ${e.message}');
    }
  }

  /// Activity를 종료하고 서버의 push token을 정리한다.
  ///
  /// [matchCode]가 null이면 모든 Activity를 종료한다(로그아웃 등).
  Future<void> end([String? matchCode]) async {
    if (!_isAvailable) return;

    final target = matchCode ?? _activeMatchCode;
    try {
      await _channel.invokeMethod<void>('end', {'matchCode': matchCode});
    } on PlatformException catch (e) {
      log('LiveActivityService.end error: ${e.message}');
    }

    if (target != null) {
      await _tokenRepository.removeToken(target);
    }
    if (matchCode == null || matchCode == _activeMatchCode) {
      _activeMatchCode = null;
    }
  }

  /// 네이티브에서 올라오는 push token 갱신을 서버에 저장한다.
  ///
  /// 토큰은 활동마다 다르고 수명 중에도 회전하므로 매번 upsert한다.
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onPushToken') return null;

    final args = (call.arguments as Map?)?.cast<String, dynamic>();
    final matchCode = args?['matchCode'] as String?;
    final token = args?['token'] as String?;
    if (matchCode == null || token == null || token.isEmpty) return null;

    try {
      await _tokenRepository.saveToken(matchCode: matchCode, pushToken: token);
    } catch (e) {
      log('LiveActivityService token save error: $e');
    }
    return null;
  }

  /// 네이티브로 넘길 인자 — 키 이름은 `toWidgetJson()`과 맞춘다.
  Map<String, dynamic> _payload(FavoriteMatchResponse match) {
    final w = match.toWidgetJson();
    return <String, dynamic>{
      'matchCode': match.matchCode,
      'tournament': w['tournament'],
      'meta': w['meta'],
      'team1': w['team1'],
      'team1Country': w['team1Country'],
      'team2': w['team2'],
      'team2Country': w['team2Country'],
      'current': w['current'],
      'setLabel': w['setLabel'],
      'prevSets': w['prevSets'],
      'isFinished': match.isFinished,
    };
  }
}
