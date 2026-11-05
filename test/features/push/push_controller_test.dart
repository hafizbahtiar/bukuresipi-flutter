import 'dart:async';

import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/push/push_controller.dart';
import 'package:bukuresipi_flutter/features/push/push_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes.dart';

class FakeMessaging implements PushMessaging {
  bool granted = false;
  bool answer = true; // what the system dialog answers
  int asked = 0;
  int deleted = 0;
  final refresh = StreamController<String>.broadcast();
  final taps_ = StreamController<Map<String, String>>.broadcast();
  final foreground_ = StreamController<ForegroundPush>.broadcast();
  Map<String, String>? opened;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return granted = answer;
  }

  @override
  Future<bool> allowed() async => granted;
  @override
  Future<String?> token() async => 'token-aaaaaaaaaaaaaaaaaaaa';
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Future<void> deleteToken() async => deleted++;
  @override
  Stream<ForegroundPush> get foreground => foreground_.stream;
  @override
  Future<Map<String, String>?> initialTap() async => opened;
  @override
  Stream<Map<String, String>> get taps => taps_.stream;
}

void main() {
  late FakeMessaging fcm;
  late FakeAdapter http;
  late FakeAuthRepository authRepo;
  late AuthController auth;

  Future<PushController> start({
    bool signedIn = true,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    authRepo = FakeAuthRepository()..session = signedIn;
    auth = AuthController(authRepo);
    await auth.restore();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = http;
    final push = PushController(
      fcm,
      dio,
      await SharedPreferences.getInstance(),
      auth,
      platform: 'android',
    );
    await push.start();
    await pumpEventQueue();
    return push;
  }

  List<String> calls() => [
    for (final r in http.requests) '${r.method} ${r.path} ${r.data ?? ''}',
  ];

  setUp(() {
    fcm = FakeMessaging();
    http = FakeAdapter((_) => (204, null));
  });

  test('signed in: asks once, then this phone is registered; a later share does not ask again', () async {
    final push = await start();
    await push.askOnce();
    expect(fcm.asked, 1);
    expect(push.enabled, isTrue);
    expect(calls(), [
      'PUT /push/device {token: token-aaaaaaaaaaaaaaaaaaaa, platform: android}', // sign-in
      'PUT /push/device {token: token-aaaaaaaaaaaaaaaaaaaa, platform: android}', // the share: registers again, no dialog
    ]);
  });

  test('signed out: not asked until sign-in', () async {
    await start(signedIn: false);
    expect([fcm.asked, calls()], [0, []]);
  });

  test('allowed already: registered on sign-in and on every token refresh; the switch turns it off', () async {
    fcm.granted = true;
    final push = await start(prefs: {'push.asked': true});
    fcm.refresh.add('token-bbbbbbbbbbbbbbbbbbbb');
    await pumpEventQueue();
    expect(calls().length, 2);
    await push.setEnabled(false);
    expect(push.enabled, isFalse);
    expect(calls().last, 'DELETE /push/device ');
    fcm.refresh.add('token-cccccccccccccccccccc');
    await pumpEventQueue();
    expect(calls().length, 3); // off: no new registration
  });

  test('said no at the system dialog: nothing is registered', () async {
    fcm.answer = false;
    final push = await start();
    expect([fcm.asked, push.enabled, calls()], [1, false, []]);
  });

  test('signing out replaces the token, so the next account on the phone gets its own', () async {
    fcm.granted = true;
    await start();
    await auth.logout();
    await pumpEventQueue();
    expect(fcm.deleted, 1);
  });

  test(
    'a tapped notification (also the one that opened the app) opens its share',
    () async {
      fcm.opened = {'shareId': 's-1', 'status': 'done'};
      final opened = <String>[];
      SharedPreferences.setMockInitialValues({});
      authRepo = FakeAuthRepository()..session = true;
      auth = AuthController(authRepo);
      await auth.restore();
      final push = PushController(
        fcm,
        Dio()..httpClientAdapter = http,
        await SharedPreferences.getInstance(),
        auth,
        platform: 'android',
      )
        ..onTap = opened.add
        ..onSignInTap = () => opened.add('sign-in');
      await push.start();
      fcm.taps_.add({'shareId': 's-2'});
      await pumpEventQueue();
      fcm.taps_.add({'type': 'sign_in'});
      await pumpEventQueue();
      expect(opened, ['s-1', 's-2', 'sign-in']);
    },
  );
}
