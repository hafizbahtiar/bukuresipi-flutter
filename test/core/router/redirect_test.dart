import 'package:bukuresipi_flutter/core/network/update_gate.dart';
import 'package:bukuresipi_flutter/core/router/app_router.dart';
import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

void main() {
  Future<AuthController> signedIn([User user = testUser]) async {
    final c = AuthController(FakeAuthRepository()
      ..session = true
      ..meResult = user);
    await c.restore();
    return c;
  }

  Future<AuthController> signedOut() async {
    final c = AuthController(FakeAuthRepository());
    await c.restore();
    return c;
  }

  test('signed out: private screens go to login; email links and auth screens open', () async {
    final c = await signedOut();
    final u = UpdateGate();
    expect(redirectFor('/', c, u), '/login');
    expect(redirectFor('/account', c, u), '/login');
    for (final p in ['/login', '/register', '/forgot', '/auth/reset', '/en/auth/verify']) {
      expect(redirectFor(p, c, u), isNull, reason: p);
    }
  });

  test('restoring: wait on the splash, but an email link opens at once', () async {
    final c = AuthController(FakeAuthRepository());
    expect(redirectFor('/', c, UpdateGate()), '/splash');
    expect(redirectFor('/auth/reset', c, UpdateGate()), isNull);
  });

  test('signed in: auth screens go home; owner screen only for the owner', () async {
    final u = UpdateGate();
    final user = await signedIn();
    expect(redirectFor('/login', user, u), '/');
    expect(redirectFor('/owner', user, u), '/');
    const owner = User(id: 'o', email: 'o@x.y', name: null, role: 'owner', lang: 'ms', emailVerified: true);
    expect(redirectFor('/owner', await signedIn(owner), u), isNull);
  });

  test('update required wins over everything', () async {
    final u = UpdateGate()..markRequired();
    expect(redirectFor('/', await signedIn(), u), '/update');
    expect(redirectFor('/update', await signedOut(), u), isNull);
  });
}
