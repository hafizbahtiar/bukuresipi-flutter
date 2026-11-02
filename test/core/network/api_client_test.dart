import 'dart:async';

import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

void main() {
  late MemoryTokenStore tokens;
  setUp(
    () => tokens = MemoryTokenStore(
      const Tokens(access: 'old-a', refresh: 'old-r'),
    ),
  );

  ApiClient client(FakeAdapter adapter) => ApiClient(
    baseUrl: 'https://api.test',
    tokens: tokens,
    appVersion: '1.2.3',
    adapter: adapter,
  );

  /// /me answers 401 to the old token, 200 to the new one; /refresh rotates once (a second use of old-r fails).
  (int, Object?) server(RequestOptions o, {int refreshStatus = 200}) {
    if (o.path == '/auth/refresh') {
      if ((o.data as Map)['refreshToken'] != 'old-r') {
        return (401, {'error': 'unauthorized'});
      }
      return refreshStatus == 200
          ? (200, {'accessToken': 'new-a', 'refreshToken': 'new-r'})
          : (refreshStatus, {'error': 'x'});
    }
    return o.headers['Authorization'] == 'Bearer new-a'
        ? (200, {'ok': true})
        : (401, {'error': 'unauthorized'});
  }

  test(
    'sends X-App-Version and the access token; public requests carry no token',
    () async {
      final adapter = FakeAdapter((_) => (200, {}));
      final api = client(adapter);
      await api.dio.get('/auth/me');
      await api.dio.post('/auth/login', options: ApiClient.public);
      expect(
        adapter.requests[0].uri.toString(),
        'https://api.test/api/v1/auth/me',
      );
      expect(adapter.requests[0].headers['X-App-Version'], '1.2.3');
      expect(adapter.requests[0].headers['Authorization'], 'Bearer old-a');
      expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
    },
  );

  test('a 401 refreshes once, saves the rotated tokens and retries', () async {
    final adapter = FakeAdapter(server);
    final res = await client(adapter).dio.get('/auth/me');
    expect(res.data, {'ok': true});
    expect(tokens.current!.access, 'new-a');
    expect(tokens.current!.refresh, 'new-r');
    expect(adapter.requests.map((r) => r.path), [
      '/auth/me',
      '/auth/refresh',
      '/auth/me',
    ]);
  });

  test('three requests failing together share ONE refresh (a second would reuse the rotated token)', () async {
    final gate = Completer<void>();
    final adapter = FakeAdapter((o) async {
      if (o.path == '/auth/refresh') await gate.future;
      return server(o);
    });
    final api = client(adapter);
    final calls = [api.dio.get('/a'), api.dio.get('/b'), api.dio.get('/c')];
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    final results = await Future.wait(calls);
    expect(results.map((r) => r.statusCode), [200, 200, 200]);
    expect(
      adapter.requests.where((r) => r.path == '/auth/refresh'),
      hasLength(1),
    );
  });

  test('a rejected refresh ends the session: tokens cleared, app told, original 401 surfaces', () async {
    var ended = 0;
    final api = client(FakeAdapter((o) => server(o, refreshStatus: 401)))
      ..onSessionEnded = () => ended++;
    final error = await api.dio
        .get('/auth/me')
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(ApiException.from(error!).status, 401);
    expect(tokens.current, isNull);
    expect(ended, 1);
  });

  test(
    'a refresh that fails for another reason (offline, 500) keeps the session',
    () async {
      var ended = 0;
      final api = client(FakeAdapter((o) => server(o, refreshStatus: 500)))
        ..onSessionEnded = () => ended++;
      await expectLater(api.dio.get('/auth/me'), throwsA(isA<DioException>()));
      expect(tokens.current!.refresh, 'old-r');
      expect(ended, 0);
    },
  );

  test('a 401 on a public request (wrong password) never refreshes', () async {
    final adapter = FakeAdapter((_) => (401, {'error': 'invalid_credentials'}));
    final error = await client(adapter).dio
        .post('/auth/login', options: ApiClient.public)
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(ApiException.from(error!).code, 'invalid_credentials');
    expect(adapter.requests, hasLength(1));
  });

  test('426 tells the app an update is required', () async {
    var update = 0;
    final api = client(FakeAdapter((_) => (426, {'error': 'update_required'})))
      ..onUpdateRequired = () => update++;
    await expectLater(api.dio.get('/x'), throwsA(isA<DioException>()));
    expect(update, 1);
  });

  test('ApiException: API code, network, unknown', () {
    final opts = RequestOptions(path: '/x');
    expect(
      ApiException.from(
        DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionError,
        ),
      ).code,
      'network',
    );
    expect(
      ApiException.from(
        DioException(
          requestOptions: opts,
          response: Response(
            requestOptions: opts,
            statusCode: 500,
            data: 'oops',
          ),
        ),
      ).code,
      'unknown',
    );
    expect(ApiException.from(StateError('x')).code, 'unknown');
  });
}
