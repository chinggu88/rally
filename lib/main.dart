import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Rally',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: Routes.APP,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
