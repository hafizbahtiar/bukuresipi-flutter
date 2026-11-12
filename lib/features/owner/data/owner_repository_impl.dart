import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/db_time.dart';
import '../../recipes/data/recipes_repository_impl.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_variant.dart';
import '../domain/owner.dart';
import '../domain/owner_repository.dart';

class OwnerRepositoryImpl implements OwnerRepository {
  OwnerRepositoryImpl(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async => (await _dio.get<Map<String, dynamic>>(
    path,
    queryParameters: query,
  )).data!;

  @override
  Future<OwnerStats> getStats() => apiCall(() async {
    final j = await _get('/owner/stats');
    final u = j['users'] as Map<String, dynamic>,
        s = j['shares'] as Map<String, dynamic>,
        r = j['reports'] as Map<String, dynamic>?;
    return OwnerStats(
      usersTotal: u['total'] as int,
      usersNewThisWeek: u['newThisWeek'] as int,
      sharesToday: s['today'] as int,
      failedToday: s['failedToday'] as int,
      reportsOpen: r?['open'] as int? ?? 0,
      reportsReady: r?['ready'] as int? ?? 0,
      reviewReportsOpen: j['reviewReportsOpen'] as int? ?? 0,
      ratingBursts: j['ratingBursts'] as int? ?? 0,
      testers: j['testers'] as int? ?? 0,
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
  }) => apiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/owner/meters/${Uri.encodeComponent(code)}',
      data: {'cap': ?cap, 'period': ?period, 'active': ?active},
    );
    return _meter(res.data!);
  });

  @override
  Future<List<OwnerUser>> listUsers({String? query}) => apiCall(() async {
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
          ban: switch (u['ban']) {
            final Map<String, dynamic> b => (
              until: switch (b['until']) {
                final String s => DateTime.parse(s),
                _ => null,
              },
              reason: b['reason'] as String?,
            ),
            _ => null,
          },
        ),
    ];
  });

  @override
  Future<void> endSessions(String userId) =>
      apiCall(() => _dio.post<void>('/owner/users/$userId/logout'));

  @override
  Future<void> ban(String userId, {int? days, required String reason}) =>
      apiCall(
        () => _dio.post<void>(
          '/owner/users/$userId/ban',
          data: {'days': ?days, 'reason': reason},
        ),
      );

  @override
  Future<void> unban(String userId) =>
      apiCall(() => _dio.delete<void>('/owner/users/$userId/ban'));

  @override
  Future<void> deleteUser(
    String userId, {
    required String reason,
    bool banEmail = false,
  }) => apiCall(
    () => _dio.post<void>(
      '/owner/users/$userId/delete',
      data: {'reason': reason, 'ban': banEmail},
    ),
  );

  @override
  Future<List<ReportTicket>> reports({String status = 'open'}) =>
      apiCall(() async {
        final j = await _get('/owner/reports', {'status': status});
        return [
          for (final t in (j['reports'] as List).cast<Map<String, dynamic>>())
            _ticket(t),
        ];
      });

  @override
  Future<void> resolveReport({
    required String targetType,
    required String targetId,
    required String field,
    required bool apply,
  }) => apiCall(
    () => _dio.post<void>(
      '/owner/reports/resolve',
      data: {
        'target': {'type': targetType, 'id': targetId},
        'field': field,
        'action': apply ? 'apply' : 'reject',
      },
    ),
  );

  @override
  Future<List<ReviewReportGroup>> reviewReports() => apiCall(() async {
    final j = await _get('/owner/review-reports');
    return [
      for (final r in (j['reports'] as List).cast<Map<String, dynamic>>())
        _reviewReport(r),
    ];
  });

  @override
  Future<void> resolveReviewReport({
    required String reviewId,
    required bool hide,
  }) => apiCall(
    () => _dio.post<void>(
      '/owner/review-reports/resolve',
      data: {'reviewId': reviewId, 'action': hide ? 'hide' : 'keep'},
    ),
  );

  @override
  Future<List<RatingBurst>> ratingBursts() => apiCall(() async {
    final j = await _get('/owner/rating-bursts');
    return [
      for (final b in (j['bursts'] as List).cast<Map<String, dynamic>>())
        _burst(b),
    ];
  });

  @override
  Future<void> hideRecipe(String recipeId) => apiCall(
    () => _dio.post<void>(
      '/owner/recipe-reports/resolve',
      data: {'recipeId': recipeId, 'action': 'hide'},
    ),
  );

  @override
  Future<({List<RecipeVariant> variants, bool complete})> findVariants(
    String recipeId,
  ) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/recipes/$recipeId/variants',
    )).data!;
    return (
      variants: [
        for (final v in (j['variants'] as List).cast<Map<String, dynamic>>())
          recipeVariantFromJson(v),
      ],
      complete: j['complete'] as bool? ?? true,
    );
  });

  @override
  Future<DishDraft> draftDish(String recipeId) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/recipes/$recipeId/draft',
      // A web search, up to 6 pages and an AI call: longer than the default 30 s wait.
      options: Options(receiveTimeout: const Duration(seconds: 120)),
    )).data!;
    List<String> texts(String k) => (j[k] as List).cast<String>();
    return (
      name: j['name'] as String,
      ingredients: texts('ingredients'),
      steps: texts('steps'),
      sources: [
        for (final s in (j['sources'] as List).cast<Map<String, dynamic>>())
          (url: s['url'] as String, title: s['title'] as String?),
      ],
      images: [...?(j['images'] as List?)?.cast<String>()],
      warnings: texts('warnings'),
      complete: j['complete'] as bool? ?? true,
    );
  });

  @override
  Future<RecipeDetail> setDishCover(String recipeId, String url) =>
      apiCall(() async {
        final j = (await _dio.put<Map<String, dynamic>>(
          '/owner/recipes/$recipeId/cover',
          data: {'url': url},
          // The server downloads the photo first.
          options: Options(receiveTimeout: const Duration(seconds: 60)),
        )).data!;
        return recipeDetailFromJson(j);
      });

  @override
  Future<List<OwnerPlace>> places() => apiCall(() async {
    final j = await _get('/owner/places');
    return [
      for (final p in (j['places'] as List).cast<Map<String, dynamic>>())
        OwnerPlace(
          branchId: p['branchId'] as String,
          placeId: p['placeId'] as String,
          name: p['name'] as String,
          label: p['label'] as String?,
          address: p['address'] as String?,
          city: p['city'] as String?,
          state: p['state'] as String?,
          lat: (p['lat'] as num).toDouble(),
          lng: (p['lng'] as num).toDouble(),
          pinSource: p['pinSource'] as String?,
          savers: p['savers'] as int,
        ),
    ];
  });

  @override
  Future<List<Tester>> testers() => apiCall(() async {
    final j = await _get('/owner/testers');
    return [
      for (final t in (j['testers'] as List).cast<Map<String, dynamic>>())
        Tester(
          email: t['email'] as String,
          lang: t['lang'] as String,
          joinedAt: dbTime(t['createdAt'] as String),
          invitedAt: switch (t['invitedAt']) {
            final String at => dbTime(at),
            _ => null,
          },
          emailStatus: t['emailStatus'] as String?,
        ),
    ];
  });

  @override
  Future<void> inviteTester(String email) => apiCall(
    () => _dio.post<void>('/owner/testers/invite', data: {'email': email}),
  );

  @override
  Future<void> deleteRating(String ratingId) =>
      apiCall(() => _dio.delete<void>('/owner/ratings/$ratingId'));

  @override
  Future<List<FailedShare>> failedShares() => apiCall(() async {
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

ReviewReportGroup _reviewReport(Map<String, dynamic> j) {
  final review = j['review'] as Map<String, dynamic>;
  return ReviewReportGroup(
    reviewId: review['id'] as String,
    stars: (review['stars'] as num).toInt(),
    text: review['text'] as String,
    author: review['author'] as String,
    hidden: review['hidden'] as bool? ?? false,
    createdAt: dbTime(review['createdAt'] as String),
    count: (j['count'] as num).toInt(),
    reasons: (j['reasons'] as List).cast<String>(),
    latestNote: j['latestNote'] as String?,
    updatedAt: dbTime(j['updatedAt'] as String),
  );
}

ReportTicket _ticket(Map<String, dynamic> j) {
  final target = j['target'] as Map<String, dynamic>;
  ReportValue value(Map<String, dynamic>? v) => ReportValue(
    lat: (v?['lat'] as num?)?.toDouble(),
    lng: (v?['lng'] as num?)?.toDouble(),
    value: v?['value'] as String?,
  );
  return ReportTicket(
    targetType: target['type'] as String,
    targetId: target['id'] as String,
    targetName: target['name'] as String,
    targetLabel: target['label'] as String?,
    field: j['field'] as String,
    count: j['count'] as int,
    threshold: j['threshold'] as int,
    current: value(j['current'] as Map<String, dynamic>?),
    proposed: j['proposed'] == null
        ? null
        : value(j['proposed'] as Map<String, dynamic>),
    status: j['status'] as String,
    ready: j['ready'] as bool,
    latestNote: j['latestNote'] as String?,
    verifiedAt: j['verifiedAt'] == null
        ? null
        : dbTime(j['verifiedAt'] as String),
    updatedAt: dbTime(j['updatedAt'] as String),
  );
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

RatingBurst _burst(Map<String, dynamic> j) {
  final branch = j['branch'] as Map<String, dynamic>;
  return RatingBurst(
    branchId: branch['id'] as String,
    restaurant: branch['restaurant'] as String,
    label: branch['label'] as String?,
    newAccounts: (j['newAccounts'] as num).toInt(),
    ratings: [
      for (final r in (j['ratings'] as List).cast<Map<String, dynamic>>())
        BurstRating(
          id: r['id'] as String,
          stars: (r['stars'] as num).toInt(),
          text: r['text'] as String?,
          hidden: r['hidden'] as bool? ?? false,
          createdAt: dbTime(r['createdAt'] as String),
          email: (r['user'] as Map)['email'] as String,
          joinedAt: dbTime((r['user'] as Map)['createdAt'] as String),
          emailVerified: (r['user'] as Map)['emailVerified'] as bool? ?? false,
        ),
    ],
  );
}
