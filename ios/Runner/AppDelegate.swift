import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Scene 기반 앱 + FirebaseAppDelegateProxyEnabled=false 환경에서는
    // FCM swizzling이 비활성화되므로 delegate와 토큰을 수동으로 설정한다.
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 포그라운드 알림 표시. swizzling이 꺼져 있어 Dart onMessage 스트림이 트리거되지 않으므로,
  // 네이티브에서 OS가 직접 배너를 띄우게 한다.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    Messaging.messaging().appDidReceiveMessage(userInfo)
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    Messaging.messaging().appDidReceiveMessage(userInfo)
    completionHandler()
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // swizzling이 꺼져 있으므로 APNs 토큰을 FCM에 수동 전달
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    Messaging.messaging().appDidReceiveMessage(userInfo)
    completionHandler(.newData)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // no-op: Dart 측 FirebaseMessaging.onTokenRefresh에서 처리
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
