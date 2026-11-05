import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// What the app needs from FCM, so the controller is tested with a fake.
abstract interface class PushMessaging {
  /// The system "allow notifications" answer: true = allowed. Asks only when it was never answered.
  Future<bool> requestPermission();
  Future<bool> allowed();
  Future<String?> token();
  Stream<String> get tokenRefresh;
  Future<void> deleteToken();

  /// A push that arrived while the app was open: Android shows no system notification then, so the app shows its own.
  Stream<ForegroundPush> get foreground;

  /// The data of a notification the user tapped: one that opened the app, then later ones.
  Future<Map<String, String>?> initialTap();
  Stream<Map<String, String>> get taps;
}

/// A push received while the app is open: what the system notification would have said, and its data.
typedef ForegroundPush = ({
  String? title,
  String? body,
  Map<String, String> data,
});

/// Android only for now: Firebase reads android/app/google-services.json (no firebase_options.dart). iOS needs
/// GoogleService-Info.plist and an APNs key first (bukuresipi-hono docs/fcm-setup.md).
class FirebasePushMessaging implements PushMessaging {
  static Future<FirebasePushMessaging> start() async {
    await Firebase.initializeApp();
    return FirebasePushMessaging._();
  }

  FirebasePushMessaging._();

  final _fcm = FirebaseMessaging.instance;

  static Map<String, String> _data(RemoteMessage m) => {
    for (final e in m.data.entries) e.key: '${e.value}',
  };

  @override
  Future<bool> requestPermission() async =>
      (await _fcm.requestPermission()).authorizationStatus ==
      AuthorizationStatus.authorized;

  @override
  Future<bool> allowed() async =>
      (await _fcm.getNotificationSettings()).authorizationStatus ==
      AuthorizationStatus.authorized;

  // shortcut: the classic FCM token API (deprecated in firebase_messaging 17 for register()/onRegistered, which
  // give a Firebase Installation ID). The API sends with message.token (bukuresipi-hono src/lib/push.ts); move both
  // together once FID direct-send is confirmed with FCM HTTP v1.
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _fcm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => _fcm.onTokenRefresh;

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _fcm.deleteToken();

  @override
  Stream<ForegroundPush> get foreground => FirebaseMessaging.onMessage.map(
    (m) => (
      title: m.notification?.title,
      body: m.notification?.body,
      data: _data(m),
    ),
  );

  @override
  Future<Map<String, String>?> initialTap() async {
    final m = await _fcm.getInitialMessage();
    return m == null ? null : _data(m);
  }

  @override
  Stream<Map<String, String>> get taps =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);
}
