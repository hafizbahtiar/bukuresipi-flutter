import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';

void main() {
  test('no stored session -> signed out', () async {
    final c = AuthController(FakeAuthRepository());
    await c.restore();
    expect(c.status, AuthStatus.signedOut);
  });

  test('stored session -> signed in with the fresh user', () async {
    final c = AuthController(FakeAuthRepository()..session = true);
    await c.restore();
    expect([c.status, c.user?.id], [AuthStatus.signedIn, 'u-1']);
  });

  test(
    'session ended on the server (401) -> signed out and local data cleared',
    () async {
      final repo = FakeAuthRepository()
        ..session = true
        ..cached = testUser
        ..meResult = const ApiException('unauthorized', status: 401);
      final c = AuthController(repo);
      await c.restore();
      expect(c.status, AuthStatus.signedOut);
      expect(repo.clears, 1);
    },
  );

  test('offline at launch with a saved user -> stays signed in', () async {
    final c = AuthController(
      FakeAuthRepository()
        ..session = true
        ..cached = testUser
        ..meResult = const ApiException(ApiException.network),
    );
    await c.restore();
    expect(c.status, AuthStatus.signedIn);
  });

  test(
    'a password reset signs this device out (the API ended every session)',
    () async {
      final repo = FakeAuthRepository()..session = true;
      final c = AuthController(repo);
      await c.restore();
      await c.resetPassword('token', 'a new password');
      expect(c.status, AuthStatus.signedOut);
      expect(repo.session, isFalse);
    },
  );

  test('a verified email is not reported as failed when the profile refresh is offline', () async {
    final repo = FakeAuthRepository()..session = true;
    final c = AuthController(repo);
    await c.restore();
    repo.meResult = const ApiException(ApiException.network);
    await c.verifyEmail('token'); // must not throw: the link is single-use
    expect(c.status, AuthStatus.signedIn);
  });
}
