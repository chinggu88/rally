import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/data/repositories/device_token_repository.dart';

/// FCM 푸시 알림 수신/표시/토큰 관리 전반을 담당하는 GetxService.
///
/// 책임:
///   1. 알림 권한 요청 (iOS는 OS 다이얼로그, Android 13+는 런타임 권한)
///   2. FCM 토큰 발급 + Supabase device_tokens 테이블에 저장
///   3. 토큰 갱신 이벤트 구독 → 자동 재저장
///   4. 인증 상태 구독 → 로그인 시 토큰 저장, 로그아웃 시 토큰 삭제
///   5. Foreground 메시지를 OS 알림 배너로 표시 (FCM 기본 미동작)
///   6. 알림 탭 핸들링 (notification opened app)
///
/// 호출 순서 (main.dart):
///   1. Firebase.initializeApp() 완료 후
///   2. SupabaseService.initialize() 완료 후
///   3. Get.put(NotificationService(), permanent: true)
///   4. await NotificationService.to.initialize()
class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  final DeviceTokenRepository _tokenRepo = DeviceTokenRepository();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<AuthState>? _authSub;

  /// 마지막으로 발급받은 FCM 토큰. 로그아웃 시 이 값으로 삭제 호출.
  String? _currentToken;

  /// AndroidManifest의 default_notification_channel_id와 같은 ID 사용.
  static const String _androidChannelId = 'rally_default';
  static const String _androidChannelName = 'Rally 알림';
  static const String _androidChannelDescription = 'Rally 앱의 기본 알림 채널';

  /// 한 번만 호출되도록 가드.
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _requestPermission();
      await _setupLocalNotifications();
      await _bindFcmToken();
      _bindMessageHandlers();
      _bindAuthChanges();
      await _checkInitialMessage();
      log('NotificationService.initialize: ok');
    } catch (e, st) {
      log('NotificationService.initialize: failed — $e\n$st');
    }
  }

  // ───────────────────────────────────────────────────────────
  // 1. 권한 요청
  // ───────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    log(
      'NotificationService._requestPermission: '
      '${settings.authorizationStatus}',
    );

    // 포그라운드 표시는 flutter_local_notifications로 직접 처리한다.
    // iOS에서 FCM 자체 포그라운드 표시는 flutter_local_notifications와의
    // UNUserNotificationCenter delegate 충돌로 동작하지 않으므로, FCM/OS
    // 자체 표시는 꺼서 중복/누락을 모두 방지한다.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
  }

  // ───────────────────────────────────────────────────────────
  // 2. flutter_local_notifications 초기화 (foreground 배너 표시용)
  // ───────────────────────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        log('local notification tapped: ${response.payload}');
        // TODO: payload로 라우팅 처리 (notification_id 등)
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  // ───────────────────────────────────────────────────────────
  // 3. FCM 토큰 발급 + Supabase 저장 + 갱신 구독
  // ───────────────────────────────────────────────────────────

  Future<void> _bindFcmToken() async {
    // 토큰 갱신 구독은 토큰 발급 성공 여부와 무관하게 먼저 걸어둔다.
    // (APNs 토큰이 늦게 등록되면 onTokenRefresh로 FCM 토큰이 들어온다.)
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      log('NotificationService: token refreshed');
      _currentToken = newToken;
      await _saveTokenIfLoggedIn(newToken);
    });

    // iOS는 APNs 토큰이 먼저 발급된 후에야 FCM 토큰이 발급된다.
    // requestPermission() 직후엔 아직 등록 전이라 null인 경우가 많으므로
    // 발급될 때까지 짧게 폴링한다. (시뮬레이터/프로비저닝 미설정 시 끝까지 null)
    if (Platform.isIOS) {
      final apns = await _waitForApnsToken();
      if (apns == null) {
        log(
          'NotificationService._bindFcmToken: APNs token unavailable — '
          'skip getToken (will retry via onTokenRefresh)',
        );
        return;
      }
    }

    // FCM 토큰 발급은 실패하더라도 나머지 초기화를 막지 않도록 격리한다.
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _currentToken = token;
        await _saveTokenIfLoggedIn(token);
      }
    } catch (e) {
      log('NotificationService._bindFcmToken: getToken failed — $e');
    }
  }

  /// iOS APNs 토큰이 등록될 때까지 최대 ~10초 폴링한다.
  Future<String?> _waitForApnsToken() async {
    const maxAttempts = 20;
    const interval = Duration(milliseconds: 500);
    for (var i = 0; i < maxAttempts; i++) {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null) {
        log('APNs token: ok (attempt ${i + 1})');
        return apns;
      }
      await Future.delayed(interval);
    }
    log('APNs token: still null after $maxAttempts attempts');
    return null;
  }

  Future<void> _saveTokenIfLoggedIn(String token) async {
    log('asdf _saveTokenIfLoggedIn');
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      log('NotificationService._saveTokenIfLoggedIn: skipped (anonymous)');
      return;
    }

    String? deviceName;
    String? appVersion;
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceName = info.utsname.machine;
      } else if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceName = '${info.manufacturer} ${info.model}';
      }
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (e) {
      log('NotificationService: device/app info failed — $e');
    }

    await _tokenRepo.upsertToken(
      fcmToken: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      deviceName: deviceName,
      appVersion: appVersion,
    );
  }

  // ───────────────────────────────────────────────────────────
  // 4. 메시지 핸들러 (foreground / 탭 / 콜드스타트)
  // ───────────────────────────────────────────────────────────

  void _bindMessageHandlers() {
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      log(
        'foreground message: ${message.messageId} '
        '${message.notification?.title}',
      );
      _showLocalNotification(message);
    });

    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      log('opened from background: ${message.data}');
      _handleNotificationTap(message);
    });
  }

  Future<void> _checkInitialMessage() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      log('opened from terminated: ${initial.data}');
      _handleNotificationTap(initial);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // TODO: message.data['type'] 등으로 화면 라우팅
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['notification_id'] as String?,
    );
  }

  // ───────────────────────────────────────────────────────────
  // 알림 on/off — 디바이스 토큰 등록/삭제로 구현.
  // send-push가 device_tokens를 조회하므로 토큰이 없으면 발송되지 않는다.
  // ───────────────────────────────────────────────────────────

  Future<void> setPushEnabled(bool enabled) async {
    final token = _currentToken;
    if (token == null) {
      log('NotificationService.setPushEnabled: skipped (no token)');
      return;
    }
    if (enabled) {
      await _saveTokenIfLoggedIn(token);
    } else {
      await _tokenRepo.deleteToken(token);
    }
  }

  // ───────────────────────────────────────────────────────────
  // 5. 인증 상태에 따라 토큰 저장/삭제
  // ───────────────────────────────────────────────────────────

  void _bindAuthChanges() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (state.event == AuthChangeEvent.signedIn) {
        if (_currentToken != null) {
          await _saveTokenIfLoggedIn(_currentToken!);
        }
      } else if (state.event == AuthChangeEvent.signedOut) {
        if (_currentToken != null) {
          await _tokenRepo.deleteToken(_currentToken!);
        }
      }
    });
  }

  // ───────────────────────────────────────────────────────────
  // 정리
  // ───────────────────────────────────────────────────────────

  @override
  void onClose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }
}

/// 백그라운드/종료 상태에서 도착한 FCM 메시지를 받는 핸들러.
///
/// 반드시 top-level 함수여야 하며 @pragma 어노테이션 필수.
/// 현재는 로깅만 — OS가 notification 페이로드를 자동으로 알림으로 표시한다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    // ignore: avoid_print
    print('background message: ${message.messageId}');
  }
}
