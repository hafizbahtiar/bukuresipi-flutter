import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/domain/auth_repository.dart';
import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:dio/dio.dart';

/// Answers every request with handler(request) = (status, json body). Records the requests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FutureOr<(int, Object?)> Function(RequestOptions o) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(o);
    final (status, data) = await handler(o);
    return ResponseBody.fromString(
      data == null ? '' : jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const testUser = User(
  id: 'u-1',
  email: 'a@example.com',
  name: 'Ali',
  role: 'user',
  lang: 'ms',
  emailVerified: false,
);
const userJson = {
  'id': 'u-1',
  'email': 'a@example.com',
  'name': 'Ali',
  'role': 'user',
  'lang': 'ms',
  'emailVerified': false,
};

/// AuthRepository with scripted answers.
class FakeAuthRepository implements AuthRepository {
  bool session = false;
  User? cached;
  Object? meResult = testUser; // a User, or an ApiException to throw
  Object? loginError;
  int clears = 0;
  final registered = <String>[];

  @override
  bool get hasSession => session;
  @override
  User? get cachedUser => cached;

  @override
  Future<User> me() async =>
      meResult is ApiException ? throw meResult! : meResult as User;
  final names = <String>[];

  final avatars = <String>[];
  int avatarsRemoved = 0;

  @override
  Future<User> setAvatar(String path) async {
    avatars.add(path);
    return testUser;
  }

  @override
  Future<User> removeAvatar() async {
    avatarsRemoved++;
    return testUser;
  }

  @override
  Future<Uint8List?> avatar(String userId, String avatar) async => avatarBytes;

  /// What every avatar download returns (null = none).
  Uint8List? avatarBytes;

  @override
  Future<User> setName(String name) async {
    names.add(name);
    return User(
      id: testUser.id,
      email: testUser.email,
      name: name,
      role: testUser.role,
      lang: testUser.lang,
      emailVerified: testUser.emailVerified,
    );
  }

  final kcalTargets = <int?>[];

  @override
  Future<User> setKcalTarget(int? kcal) async {
    kcalTargets.add(kcal);
    return User(
      id: testUser.id,
      email: testUser.email,
      name: testUser.name,
      role: testUser.role,
      lang: testUser.lang,
      emailVerified: testUser.emailVerified,
      kcalTarget: kcal,
    );
  }

  @override
  Future<User> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    session = true;
    return testUser;
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    String? name,
    required String lang,
  }) async {
    registered.add(email);
    return testUser;
  }

  @override
  Future<void> logout() => clearLocal();
  @override
  Future<void> clearLocal() async {
    clears++;
    session = false;
    cached = null;
  }

  @override
  Future<void> verifyEmail(String token) async {}
  var resends = 0;
  @override
  Future<void> resendVerification() async => resends++;
  @override
  Future<void> forgotPassword(String email) async {}
  @override
  Future<void> resetPassword(String token, String password) async {}
  @override
  Future<void> changePassword(String current, String next) async {}

  final emailChanges = <String>[];
  Object? changeEmailError;
  @override
  Future<void> changeEmail(String email, String password) async {
    if (changeEmailError != null) throw changeEmailError!;
    emailChanges.add(email);
  }

  final googleTokens = <String>[];
  @override
  Future<User> loginWithGoogle(String idToken, String lang) async {
    if (loginError != null) throw loginError!;
    googleTokens.add(idToken);
    session = true;
    return cached = testUser;
  }

  User _with({required bool google}) => User(
    id: testUser.id,
    email: testUser.email,
    name: testUser.name,
    role: testUser.role,
    lang: testUser.lang,
    emailVerified: testUser.emailVerified,
    hasPassword: (cached ?? testUser).hasPassword,
    google: google,
  );
  Object? linkError;
  @override
  Future<User> linkGoogle(String idToken) async {
    if (linkError != null) throw linkError!;
    googleTokens.add('link:$idToken');
    return cached = _with(google: true);
  }

  @override
  Future<User> unlinkGoogle() async {
    if (linkError != null) throw linkError!;
    return cached = _with(google: false);
  }

  @override
  Future<void> deleteAccountWithGoogle(String idToken) async {
    if (deleteError != null) throw deleteError!;
    deleted.add('google:$idToken');
    await clearLocal();
  }

  final deleted = <String>[];
  Object? deleteError;
  @override
  Future<void> deleteAccount(String email, String password) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(email);
    await clearLocal();
  }
}
