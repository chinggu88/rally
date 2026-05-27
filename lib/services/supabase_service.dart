import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 클라이언트 초기화 및 전역 접근을 담당하는 GetxService.
///
/// 호출 순서:
/// 1. `main()`에서 `await dotenv.load(fileName: '.env')`
/// 2. `await SupabaseService.initialize()` — `.env`의 `SUPABASE_URL`/`SUPABASE_ANON_KEY`로 Supabase 부팅
/// 3. `Get.put(SupabaseService())` — 전역 인스턴스 등록
///
/// 사용 측(Repository)에서는 `Supabase.instance.client.functions.invoke(...)`로
/// Edge Function을 호출하면 된다. 본 서비스는 그 외 보조 헬퍼/접근자를 제공한다.
class SupabaseService extends GetxService {
  /// Singleton accessor
  static SupabaseService get to => Get.find();

  /// .env 키: Supabase 프로젝트 URL
  static const String _envUrlKey = 'SUPABASE_URL';

  /// .env 키: Supabase Anon Key
  static const String _envAnonKey = 'SUPABASE_ANON_KEY';

  /// Supabase 클라이언트가 정상 초기화되었는지 여부
  bool get isReady => _initialized;
  static bool _initialized = false;

  /// 전역 Supabase 클라이언트 접근자
  ///
  /// `Supabase.initialize`가 선행되지 않으면 `AssertionError` 가 발생한다.
  SupabaseClient get client => Supabase.instance.client;

  /// `.env`에서 키를 읽어 Supabase를 초기화한다.
  ///
  /// `main()`에서 `runApp` 전에 호출되어야 한다.
  ///
  /// [debug] true면 Supabase SDK의 디버그 로깅을 활성화한다.
  static Future<void> initialize({bool debug = false}) async {
    final url = dotenv.maybeGet(_envUrlKey);
    final anonKey = dotenv.maybeGet(_envAnonKey);

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      log(
        'SupabaseService.initialize: missing $_envUrlKey/$_envAnonKey in .env. '
        'Supabase 클라이언트를 초기화하지 않고 진행합니다. '
        'lib/.env 또는 프로젝트 루트 .env에 두 키를 설정해주세요.',
      );
      _initialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: debug,
      );
      _initialized = true;
      log('SupabaseService.initialize: Supabase client ready.');
    } catch (e) {
      _initialized = false;
      log('SupabaseService.initialize error: $e');
      rethrow;
    }
  }
}
