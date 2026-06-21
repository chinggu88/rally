import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:rally/app/bindings/initial_binding.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 세로 방향 고정 (가로모드 차단)
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Firebase 초기화
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // FCM 백그라운드 메시지 핸들러 등록 (top-level 함수여야 함)
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Crashlytics: Flutter 프레임워크 에러 자동 수집
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // .env 로드 (SUPABASE_URL / SUPABASE_ANON_KEY)
      // 키 누락 시에도 앱은 부팅되도록 예외를 흡수하고 로깅만 한다.
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('main: dotenv.load failed — $e');
      }

      // Supabase 클라이언트 초기화 (.env에 키가 있을 때만 실제 부팅됨)
      await SupabaseService.initialize();

      runApp(const MyApp());
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder:
          (context, child) => GetMaterialApp(
            title: 'Rally',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            initialRoute: Routes.APP,
            getPages: AppPages.routes,
            initialBinding: InitialBinding(),
            unknownRoute: GetPage(
              name: '/notfound',
              page: () => const SizedBox.shrink(),
            ),
            debugShowCheckedModeBanner: false,
          ),
    );
  }
}
