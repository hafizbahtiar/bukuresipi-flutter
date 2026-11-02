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
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    final (status, data) = await handler(o);
    return ResponseBody.fromString(data == null ? '' : jsonEncode(data), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

const testUser = User(id: 'u-1', email: 'a@example.com', name: 'Ali', role: 'user', lang: 'ms', emailVerified: false);
const userJson = {'id': 'u-1', 'email': 'a@example.com', 'name': 'Ali', 'role': 'user', 'lang': 'ms', 'emailVerified': false};

/// AuthRepository with scripted answers.
class FakeAuthRepository implements AuthRepository {
  bool session = false;
  User? cached;
  Object? meResult = testUser; // a User, or an ApiException to throw
  Object? loginError;
  int clears = 0;

  @override
  bool get hasSession => session;
  @override
  User? get cachedUser => cached;

  @override
  Future<User> me() async => meResult is ApiException ? throw meResult! : meResult as User;
  @override
  Future<User> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    session = true;
    return testUser;
  }

  @override
  Future<User> register({required String email, required String password, String? name, required String lang}) async => testUser;
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
  @override
  Future<void> resendVerification() async {}
  @override
  Future<void> forgotPassword(String email) async {}
  @override
  Future<void> resetPassword(String token, String password) async {}
  @override
  Future<void> changePassword(String current, String next) async {}
}
