import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';

/// /api/v1/auth/* calls, raw JSON in and out. Errors surface as DioException (mapped by the repository).
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  static const _channel = MethodChannel('bukuresipi/device');

  /// What this phone is called in "Signed-in devices". No name (iOS for now, tests) = the API shows none.
  static Future<Map<String, String?>> device() async {
    String? name;
    try {
      name = await _channel.invokeMethod<String>('name');
    } catch (_) {}
    return {'name': name, 'platform': Platform.isIOS ? 'ios' : 'android'};
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Object? body, {
    bool auth = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: auth ? null : ApiClient.public,
    );
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async =>
      _post('/auth/register', {...body, 'device': await device()});
  Future<Map<String, dynamic>> login(String email, String password) async =>
      _post('/auth/login', {
        'email': email,
        'password': password,
        'device': await device(),
      });
  Future<void> logout(String refreshToken) =>
      _post('/auth/logout', {'refreshToken': refreshToken});
  Future<void> verifyEmail(String token) =>
      _post('/auth/verify-email', {'token': token});
  Future<void> resendVerification() =>
      _post('/auth/resend-verification', null, auth: true);
  Future<void> forgotPassword(String email) =>
      _post('/auth/forgot-password', {'email': email});
  Future<void> deleteAccount(String email, String password) =>
      _post('/auth/delete-account', {'email': email, 'password': password});
  Future<void> resetPassword(String token, String password) =>
      _post('/auth/reset-password', {'token': token, 'password': password});
  Future<void> changeEmail(String email, String password) => _post(
    '/auth/change-email',
    {'email': email, 'password': password},
    auth: true,
  );
  Future<Map<String, dynamic>> changePassword(String current, String next) =>
      _post('/auth/change-password', {
        'currentPassword': current,
        'newPassword': next,
      }, auth: true);

  Future<List<Map<String, dynamic>>> sessions() async =>
      ((await _dio.get<Map<String, dynamic>>('/auth/sessions'))
                  .data!['sessions']
              as List)
          .cast<Map<String, dynamic>>();
  Future<void> endSession(String id) => _dio.delete<void>('/auth/sessions/$id');
  Future<void> endOtherSessions() => _dio.delete<void>('/auth/sessions/others');

  Future<Map<String, dynamic>> me() async =>
      (await _dio.get<Map<String, dynamic>>('/auth/me')).data!;

  Future<Map<String, dynamic>> setName(String name) async =>
      (await _dio.patch<Map<String, dynamic>>(
        '/auth/me',
        data: {'name': name},
      )).data!;
}
