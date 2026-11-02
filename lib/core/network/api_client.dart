import 'package:dio/dio.dart';

import '../log.dart';
import '../storage/token_store.dart';

/// The one Dio for the API (`<baseUrl>/api/v1`). Every request carries `X-App-Version` (the API answers 426 when the
/// app is too old) and, unless `extra: {'auth': false}`, the access token. A 401 on an authenticated request
/// refreshes the session once (shared by concurrent requests: refresh tokens rotate, so a second refresh with the
/// same token would fail) and retries. A rejected refresh ends the session.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokens,
    required String appVersion,
    HttpClientAdapter? adapter,
  }) {
    final options = BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'X-App-Version': appVersion},
      contentType: Headers.jsonContentType,
    );
    dio = Dio(options);
    _bare = Dio(options);
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      _bare.httpClientAdapter = adapter;
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
        onResponse: (r, h) {
          log('<- ${r.statusCode} ${r.requestOptions.path}');
          h.next(r);
        },
      ),
    );
  }

  final TokenStore tokens;
  late final Dio dio;
  late final Dio _bare; // no interceptors: the refresh call itself

  /// Set by the app: the session ended (refresh rejected). Tokens are already cleared.
  void Function()? onSessionEnded;

  /// Set by the app: the API refused this app version (426).
  void Function()? onUpdateRequired;

  /// Requests that must not carry the token (login, register, ...).
  static final public = Options(extra: {'auth': false});

  Future<_Refresh>? _refreshing;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log('-> ${options.method} ${options.path}');
    final access = tokens.current?.access;
    if (options.extra['auth'] != false && access != null) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final res = error.response;
    log(
      '<- ${res?.statusCode ?? error.type.name} ${error.requestOptions.path} ${res?.data is Map ? (res!.data as Map)['error'] : ''}',
    );
    final options = error.requestOptions;
    if (res?.statusCode == 426) onUpdateRequired?.call();
    final sent = options.headers['Authorization'];
    if (res?.statusCode != 401 ||
        sent == null ||
        options.extra['retried'] == true) {
      return handler.next(error);
    }

    // Another request may have refreshed already: then just retry with the new token.
    final current = tokens.current;
    if (current != null && sent != 'Bearer ${current.access}') {
      return _retry(options, handler, error);
    }
    if (current == null) return handler.next(error);

    final outcome = await (_refreshing ??= _refresh(current.refresh)
        .whenComplete(() => _refreshing = null));
    if (outcome == _Refresh.ok) return _retry(options, handler, error);
    if (outcome == _Refresh.rejected) {
      await tokens.clear();
      onSessionEnded?.call();
    }
    handler.next(error);
  }

  Future<_Refresh> _refresh(String refreshToken) async {
    try {
      final res = await _bare.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      await tokens.save(Tokens.fromJson(res.data!));
      return _Refresh.ok;
    } on DioException catch (e) {
      // 401 = session gone (expired, logged out elsewhere, password changed). Anything else: keep the session.
      return e.response?.statusCode == 401
          ? _Refresh.rejected
          : _Refresh.failed;
    }
  }

  Future<void> _retry(
    RequestOptions options,
    ErrorInterceptorHandler handler,
    DioException original,
  ) async {
    options.extra['retried'] = true;
    try {
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(original);
    }
  }
}

enum _Refresh { ok, rejected, failed }
