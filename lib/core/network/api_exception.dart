import 'package:dio/dio.dart';

import '../log.dart';

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
      final code = data is Map && data['error'] is String
          ? data['error'] as String
          : unknown;
      return ApiException(code, status: res.statusCode);
    }
    // Not an HTTP failure: usually a response the parser did not expect. Say so in debug builds.
    log('unexpected error: $error');
    return const ApiException(unknown);
  }

  @override
  String toString() => 'ApiException($code, $status)';
}

/// Runs an API call: any failure comes out as an [ApiException].
Future<T> apiCall<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } catch (e) {
    throw ApiException.from(e);
  }
}
