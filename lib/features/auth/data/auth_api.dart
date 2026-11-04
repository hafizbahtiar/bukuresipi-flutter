import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// /api/v1/auth/* calls, raw JSON in and out. Errors surface as DioException (mapped by the repository).
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

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

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) =>
      _post('/auth/register', body);
  Future<Map<String, dynamic>> login(String email, String password) =>
      _post('/auth/login', {'email': email, 'password': password});
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
  Future<Map<String, dynamic>> changePassword(String current, String next) =>
      _post('/auth/change-password', {
        'currentPassword': current,
        'newPassword': next,
      }, auth: true);

  Future<Map<String, dynamic>> me() async =>
      (await _dio.get<Map<String, dynamic>>('/auth/me')).data!;
}
