import 'package:dio/dio.dart';

/// Any failed API call. [code] is the API's `error` field (`invalid_credentials`, `rate_limited`, ...), or
/// `network` (no response) / `unknown`. Screens map codes to text; nothing else inspects Dio errors.
class ApiException implements Exception {
  const ApiException(this.code, {this.status});

  final String code;
  final int? status;

  static const network = 'network';
  static const unknown = 'unknown';

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final res = error.response;
      if (res == null) return const ApiException(network);
      final data = res.data;
      final code = data is Map && data['error'] is String ? data['error'] as String : unknown;
      return ApiException(code, status: res.statusCode);
    }
    return const ApiException(unknown);
  }

  @override
  String toString() => 'ApiException($code, $status)';
}
