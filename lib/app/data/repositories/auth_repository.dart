import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

/// 인증 관련 Supabase 호출 레포지토리.
///
<<<<<<< HEAD
/// 이메일/비밀번호 로그인·회원가입과 Apple/Google/Kakao OAuth 로그인을 담당한다.
=======
/// 이메일/비밀번호 로그인·회원가입과 Apple/Google OAuth 로그인을 담당한다.
>>>>>>> f9cd20d7904e4fdc5c101de04c95d6a3807bae5c
/// 모든 OAuth는 `signInWithOAuth` + 딥링크 콜백(`io.supabase.rally://login-callback/`)
/// 으로 처리되며, 딥링크 수신과 세션 교환은 `supabase_flutter`가 자동 처리한다.
class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// OAuth/이메일 confirm 콜백 URL.
  /// iOS Info.plist의 CFBundleURLSchemes, AndroidManifest.xml의 intent-filter,
  /// Supabase 대시보드의 Redirect URLs와 완전히 일치해야 한다.
  static const String _redirectUrl = 'io.supabase.rally://login-callback/';

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      log('AuthRepository.signInWithEmail AuthException: ${e.message}');
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _redirectUrl,
      );
    } on AuthException catch (e) {
      log('AuthRepository.signUpWithEmail AuthException: ${e.message}');
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() => _oauth(OAuthProvider.google);
  Future<bool> signInWithApple() => _oauth(OAuthProvider.apple);
<<<<<<< HEAD
  Future<bool> signInWithKakao() => _oauth(OAuthProvider.kakao);
=======
>>>>>>> f9cd20d7904e4fdc5c101de04c95d6a3807bae5c

  Future<bool> _oauth(OAuthProvider provider) async {
    try {
      return await _client.auth.signInWithOAuth(
        provider,
        redirectTo: _redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      log('AuthRepository._oauth($provider) AuthException: ${e.message}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      log('AuthRepository.signOut AuthException: ${e.message}');
      rethrow;
    }
  }
}
