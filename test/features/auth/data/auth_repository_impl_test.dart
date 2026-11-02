import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:bukuresipi_flutter/features/auth/data/auth_api.dart';
import 'package:bukuresipi_flutter/features/auth/data/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes.dart';

void main() {
  late MemoryTokenStore tokens;
  late SharedPreferences prefs;

  Future<(AuthRepositoryImpl, FakeAdapter)> make((int, Object?) Function(String path, Object? body) answer) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tokens = MemoryTokenStore();
    final adapter = FakeAdapter((o) => answer(o.path, o.data));
    final api = ApiClient(baseUrl: 'https://api.test', tokens: tokens, appVersion: '1.0.0', adapter: adapter);
    return (AuthRepositoryImpl(AuthApi(api.dio), tokens, prefs), adapter);
  }

  test('login trims the email, stores the tokens and remembers the user for offline launch', () async {
    final (repo, adapter) = await make((_, _) => (200, {'user': userJson, 'accessToken': 'a', 'refreshToken': 'r'}));
    final user = await repo.login('  a@example.com ', 'pw');
    expect((adapter.requests.single.data as Map)['email'], 'a@example.com');
    expect(user.id, 'u-1');
    expect(repo.hasSession, isTrue);
    expect(repo.cachedUser!.email, 'a@example.com');
  });

  test('register sends lang and leaves out an empty name', () async {
    final (repo, adapter) = await make((_, _) => (201, {'user': userJson, 'accessToken': 'a', 'refreshToken': 'r'}));
    await repo.register(email: 'a@example.com', password: 'longenough', name: '  ', lang: 'en');
    expect(adapter.requests.single.data, {'email': 'a@example.com', 'password': 'longenough', 'lang': 'en'});
  });

  test('API errors come out as ApiException with the code', () async {
    final (repo, _) = await make((_, _) => (409, {'error': 'email_taken'}));
    await expectLater(
      repo.register(email: 'a@example.com', password: 'longenough', lang: 'ms'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'email_taken')),
    );
    expect(repo.hasSession, isFalse);
  });

  test('logout clears this device even when the server call fails', () async {
    final (repo, _) = await make((path, _) => path == '/auth/logout' ? (500, {'error': 'internal'}) : (200, {'user': userJson, 'accessToken': 'a', 'refreshToken': 'r'}));
    await repo.login('a@example.com', 'pw');
    await repo.logout();
    expect(repo.hasSession, isFalse);
    expect(repo.cachedUser, isNull);
  });

  test('change password keeps this device signed in with the new tokens', () async {
    final (repo, _) = await make((_, _) => (200, {'accessToken': 'a2', 'refreshToken': 'r2'}));
    await tokens.save(const Tokens(access: 'a1', refresh: 'r1'));
    await repo.changePassword('old pw', 'new password');
    expect(tokens.current!.refresh, 'r2');
  });
}
