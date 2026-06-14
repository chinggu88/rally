import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'firebase_options.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics: Flutter 프레임워크 에러 자동 수집
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
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

    // 전역 GetxService 등록 (Get.find()로 접근 가능)
    Get.put(SupabaseService(), permanent: true);

    runApp(const MyApp());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
            debugShowCheckedModeBanner: false,
          ),
    );
  }
}
