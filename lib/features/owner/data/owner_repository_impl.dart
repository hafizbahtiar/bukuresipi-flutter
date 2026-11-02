import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/db_time.dart';
import '../domain/owner.dart';
import '../domain/owner_repository.dart';

class OwnerRepositoryImpl implements OwnerRepository {
  OwnerRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async => (await _dio.get<Map<String, dynamic>>(
    path,
    queryParameters: query,
  )).data!;

  @override
  Future<OwnerStats> getStats() => _call(() async {
    final j = await _get('/owner/stats');
    final u = j['users'] as Map<String, dynamic>,
        s = j['shares'] as Map<String, dynamic>;
    return OwnerStats(
      usersTotal: u['total'] as int,
      usersNewThisWeek: u['newThisWeek'] as int,
      sharesToday: s['today'] as int,
      failedToday: s['failedToday'] as int,
      meters: [
        for (final m in j['meters'] as List) _meter(m as Map<String, dynamic>),
      ],
    );
  });

  @override
  Future<Meter> updateMeter(
    String code, {
    int? cap,
    String? period,
    bool? active,
  }) => _call(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/owner/meters/${Uri.encodeComponent(code)}',
      data: {'cap': ?cap, 'period': ?period, 'active': ?active},
    );
    return _meter(res.data!);
  });

  @override
  Future<List<OwnerUser>> listUsers({String? query}) => _call(() async {
    final q = query?.trim();
    final j = await _get('/owner/users', {
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return [
      for (final u in (j['users'] as List).cast<Map<String, dynamic>>())
        OwnerUser(
          id: u['id'] as String,
          email: u['email'] as String,
          role: u['role'] as String,
          verified: u['verified'] as bool,
          createdAt: dbTime(u['createdAt'] as String),
          shares: u['shares'] as int,
        ),
    ];
  });

  @override
  Future<void> endSessions(String userId) =>
      _call(() => _dio.post<void>('/owner/users/$userId/logout'));

  @override
  Future<List<FailedShare>> failedShares() => _call(() async {
    final j = await _get('/owner/shares');
    return [
      for (final s in (j['shares'] as List).cast<Map<String, dynamic>>())
        FailedShare(
          id: s['id'] as String,
          createdAt: dbTime(s['createdAt'] as String),
          status: s['status'] as String,
          kind: s['kind'] as String,
          input: s['input'] as String,
          gaps: (s['gaps'] as List).cast<String>(),
          platform: s['platform'] as String?,
          sourceUrl: s['sourceUrl'] as String?,
          error: s['error'] as String?,
          caption: s['caption'] as String?,
        ),
    ];
  });
}

Meter _meter(Map<String, dynamic> m) => Meter(
  code: m['code'] as String,
  name: m['name'] as String,
  used: m['used'] as int,
  cap: m['cap'] as int,
  period: m['period'] as String? ?? 'month',
  active: m['active'] as bool,
  vendorUrl: m['vendorUrl'] as String?,
);
