import 'dart:developer';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_response.dart';

/// 사용자 프로필(`profiles` 테이블)과 아바타(`avatars` 스토리지 버킷)를
/// 다루는 레포지토리.
///
/// 유저 스코프 데이터이므로 Edge Function이 아니라 직접 `.from()` + RLS로
/// 접근한다([DeviceTokenRepository]와 동일 패턴).
class ProfileRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'profiles';
  static const String _bucket = 'avatars';

  /// 현재 로그인 사용자의 프로필을 조회한다.
  ///
  /// 가입 트리거로 행이 자동 생성되지만, 트리거 이전 가입자/유실 대비로
  /// 행이 없으면 빈 행을 upsert해 생성한 뒤 반환한다.
  /// 비로그인 시 null.
  Future<ProfileResponse?> fetchMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row =
          await _client.from(_table).select().eq('id', user.id).maybeSingle();

      if (row != null) {
        return ProfileResponse.fromJson(row);
      }

      // 행이 없으면 생성 후 반환 (폴백)
      final created =
          await _client.from(_table).upsert({'id': user.id}).select().single();
      return ProfileResponse.fromJson(created);
    } on PostgrestException catch (e) {
      log('ProfileRepository.fetchMyProfile Postgrest: ${e.message}');
      rethrow;
    }
  }

  /// 닉네임 갱신.
  Future<void> updateNickname(String nickname) async {
    final user = _requireUser();
    await _client
        .from(_table)
        .update({'nickname': nickname.trim()})
        .eq('id', user.id);
  }

  /// 알림 on/off 플래그 갱신.
  Future<void> updateNotificationsEnabled(bool enabled) async {
    final user = _requireUser();
    await _client
        .from(_table)
        .update({'notifications_enabled': enabled})
        .eq('id', user.id);
  }

  /// 아바타 이미지를 스토리지에 업로드하고 `avatar_url`을 갱신한다.
  ///
  /// 경로: `avatars/{uid}/avatar_{ts}.jpg` (RLS가 {uid} 폴더만 허용).
  /// 반환값은 새 public URL.
  Future<String> uploadAvatar(File file) async {
    final user = _requireUser();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _extOf(file.path);
    final path = '${user.id}/avatar_$ts.$ext';

    final session = _client.auth.currentSession;
    log(
      'avatar upload uid=${user.id} '
      'role=${session?.user.role} '
      'expiresAt=${session?.expiresAt} '
      'isExpired=${session?.isExpired}',
    );

    try {
      await _client.storage
          .from(_bucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _contentTypeOf(ext),
            ),
          );

      final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);
      // 캐시 무력화를 위해 버전 쿼리 부착
      final url = '$publicUrl?v=$ts';

      await _client.from(_table).update({'avatar_url': url}).eq('id', user.id);
      return url;
    } on StorageException catch (e) {
      log('ProfileRepository.uploadAvatar Storage: ${e.message}');
      rethrow;
    }
  }

  /// 아바타 제거 — `avatar_url`을 null로 설정.
  ///
  /// 스토리지 객체 자체는 다음 업로드 시 upsert로 대체되므로 굳이 삭제하지
  /// 않고 참조만 끊는다(단순화).
  Future<void> removeAvatar() async {
    final user = _requireUser();
    await _client.from(_table).update({'avatar_url': null}).eq('id', user.id);
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user;
  }

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    final ext = path.substring(dot + 1).toLowerCase();
    return ext.isEmpty ? 'jpg' : ext;
  }

  static String _contentTypeOf(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
