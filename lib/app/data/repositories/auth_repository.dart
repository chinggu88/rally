import 'dart:convert';
import 'dart:developer';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 인증 관련 Supabase 호출 레포지토리.
///
/// 이메일/비밀번호 로그인·회원가입과 Apple/Google OAuth 로그인을 담당한다.
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

  /// Apple 네이티브 로그인 (iOS 시스템 시트 사용, 외부 브라우저 없음).
  ///
  /// `sign_in_with_apple`로 identityToken을 받은 뒤 Supabase `signInWithIdToken`
  /// 으로 세션을 교환한다. nonce는 raw/hashed 쌍으로 만들어 replay 공격을 방지한다.
  Future<AuthResponse> signInWithAppleNative() async {
    try {
      final rawNonce = _generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Apple identityToken이 null입니다.');
      }

      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on AuthException catch (e) {
      log('AuthRepository.signInWithAppleNative AuthException: ${e.message}');
      rethrow;
    }
  }

  String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

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
