import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log.dart';
import '../../core/network/api_exception.dart';
import '../auth/presentation/auth_controller.dart';
import 'push_messaging.dart';

/// "Your share is ready" pushes (bukuresipi-hono docs/superpowers/specs/2026-11-05-push-notifications-design.md).
/// The system permission is asked once, right after sign-in (or the first share, whichever comes first). The device is registered with the API
/// on every sign-in and token refresh while it is on; sign-out needs nothing (the session's device goes with it), but
/// the token is replaced so the next account on this phone gets its own.
class PushController extends ChangeNotifier {
  PushController(
    this._messaging,
    this._dio,
    this._prefs,
    this._auth, {
    String? platform,
  }) : _platform = platform ?? (Platform.isIOS ? 'ios' : 'android');

  final PushMessaging _messaging;
  final Dio _dio;
  final SharedPreferences _prefs;
  final AuthController _auth;
  final String _platform;
  final _subs = <StreamSubscription<Object?>>[];
  AuthStatus? _lastStatus;

  static const _askedKey = 'push.asked';
  static const _offKey = 'push.off';

  /// A share's push arrived while the app is open: reload what it changed and show it in the app.
  void Function(ForegroundPush push)? onForeground;

  /// The user tapped a share's notification: open it.
  void Function(String shareId)? onTap;

  /// The user tapped a "new sign-in to your account" alert (sent to the account's other phones at each login).
  VoidCallback? onSignInTap;

  bool _allowed = false;

  /// The Account switch: on when the system allows notifications and the user did not turn them off here.
  bool get enabled => _allowed && !(_prefs.getBool(_offKey) ?? false);

  Future<void> start() async {
    _allowed = await _messaging.allowed();
    log(
      'push: started, notifications ${_allowed ? 'allowed' : 'not allowed yet'}',
    );
    _auth.addListener(_authChanged);
    _subs
      ..add(_messaging.tokenRefresh.listen(_register))
      ..add(_messaging.foreground.listen((p) => onForeground?.call(p)))
      ..add(_messaging.taps.listen(_tapped));
    final first = await _messaging.initialTap();
    if (first != null) _tapped(first);
    _authChanged();
    notifyListeners();
  }

  void _tapped(Map<String, String> data) {
    final id = data['shareId'];
    if (id != null && id.isNotEmpty) return onTap?.call(id);
    if (data['type'] == 'sign_in') onSignInTap?.call();
  }

  void _authChanged() {
    final status = _auth.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    if (status == AuthStatus.signedIn) {
      unawaited(
        askOnce(),
      ); // registers when it was asked before, or when the answer is yes
    } else if (status == AuthStatus.signedOut) {
      unawaited(_messaging.deleteToken().catchError((_) {}));
    }
  }

  /// The system dialog, once per install: after sign-in, or after a share. Later calls only register.
  Future<void> askOnce() async {
    if (_prefs.getBool(_askedKey) ?? false) return _register();
    await _prefs.setBool(_askedKey, true);
    _allowed = await _messaging.requestPermission();
    log('push: asked, ${_allowed ? 'allowed' : 'refused'}');
    notifyListeners();
    await _register();
  }

  /// The Account switch. On asks the system again (it may say no: then it stays off).
  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(_offKey, !on);
    if (on) {
      _allowed = await _messaging.requestPermission();
      await _register();
    } else {
      try {
        await apiCall(() => _dio.delete<void>('/push/device'));
      } catch (e) {
        log('push: unregister failed, ${ApiException.from(e).code}');
      }
    }
    notifyListeners();
  }

  /// Saves this phone for the signed-in session. Failures only log: the app works without pushes.
  Future<void> _register([String? refreshed]) async {
    if (!enabled || _auth.status != AuthStatus.signedIn) {
      if (_auth.status == AuthStatus.signedIn) {
        log('push: device not saved (notifications off)');
      }
      return;
    }
    try {
      final token = refreshed ?? await _messaging.token();
      if (token == null) return;
      await apiCall(
        () => _dio.put<void>(
          '/push/device',
          data: {'token': token, 'platform': _platform},
        ),
      );
      log('push: device saved');
    } catch (e) {
      log('push: register failed, ${ApiException.from(e).code}');
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_authChanged);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
