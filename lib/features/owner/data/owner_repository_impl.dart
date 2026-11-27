import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
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
  Future<bool> ban(String userId, {int? days, required String reason}) =>
      apiCall(
        () async =>
            (await _dio.post<Map<String, dynamic>>(
              '/owner/users/$userId/ban',
              data: {'days': ?days, 'reason': reason},
            )).data?['emailed'] !=
            false,
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
  Future<({List<HiddenRecipe> recipes, List<HiddenReview> reviews})>
  hiddenContent() => apiCall(() async {
    final j = await _get('/owner/hidden');
    return (
      recipes: [
        for (final r in (j['recipes'] as List).cast<Map<String, dynamic>>())
          HiddenRecipe(
            id: r['id'] as String,
            name: r['name'] as String,
            owner: r['owner'] as String?,
            public: r['public'] as bool,
            hiddenAt: dbTime(r['hiddenAt'] as String),
          ),
      ],
      reviews: [
        for (final r in (j['reviews'] as List).cast<Map<String, dynamic>>())
          HiddenReview(
            id: r['id'] as String,
            stars: (r['stars'] as num).toInt(),
            text: r['text'] as String?,
            author: r['author'] as String,
            place: r['place'] as String,
            hiddenAt: dbTime(r['hiddenAt'] as String),
          ),
      ],
    );
  });

  @override
  Future<void> unhideRecipe(String recipeId) =>
      apiCall(() => _dio.delete<void>('/owner/recipes/$recipeId/hidden'));

  @override
  Future<void> unhideReview(String reviewId) =>
      apiCall(() => _dio.delete<void>('/owner/reviews/$reviewId/hidden'));

  @override
  Future<({List<RecipeVariant> variants, bool complete})> findVariants(
    String recipeId,
  ) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/recipes/$recipeId/variants',
      // A web search, each page read and every line named by the AI: past the default 30 s.
      options: Options(receiveTimeout: const Duration(seconds: 180)),
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
      options: Options(receiveTimeout: const Duration(seconds: 180)),
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

  @override
  Future<({List<IngredientGap> gaps, List<String> categories})>
  ingredientGaps() => apiCall(() async {
    final j = await _get('/owner/ingredients/gaps');
    return (
      gaps: [
        for (final g in (j['gaps'] as List).cast<Map<String, dynamic>>())
          IngredientGap(
            key: g['key'] as String,
            sample: g['sample'] as String,
            recipeLines: g['recipeLines'] as int,
            shoppingLines: g['shoppingLines'] as int,
          ),
      ],
      categories: (j['categories'] as List).cast<String>(),
    );
  });

  @override
  Future<List<String>> searchIngredients(String query) => apiCall(() async {
    final j = await _get('/recipes/ingredients', {'q': query});
    return [
      for (final i in (j['ingredients'] as List).cast<Map<String, dynamic>>())
        i['name'] as String,
    ];
  });

  Future<Map<String, dynamic>> _alias(
    String ingredient,
    String alias, {
    required bool preview,
  }) async => (await _dio.post<Map<String, dynamic>>(
    '/owner/ingredients/aliases',
    data: {'ingredient': ingredient, 'alias': alias, 'preview': preview},
  )).data!;

  @override
  Future<({int lines, List<String> sample})> previewAlias(
    String ingredient,
    String alias,
  ) => apiCall(() async {
    final j = await _alias(ingredient, alias, preview: true);
    return (
      lines: j['lines'] as int,
      sample: (j['sample'] as List).cast<String>(),
    );
  });

  @override
  Future<List<IngredientRow>> listIngredients() => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>('/owner/ingredients'))
        .data!;
    return [
      for (final i in (j['ingredients'] as List).cast<Map<String, dynamic>>())
        (
          id: i['id'] as int,
          name: i['name'] as String,
          category: i['category'] as String?,
          aliases: i['aliases'] as int,
        ),
    ];
  });

  static IngredientDetail _detail(Map<String, dynamic> j) => (
    id: j['id'] as int,
    name: j['name'] as String,
    category: j['category'] as String?,
    aliases: (j['aliases'] as List).cast<String>(),
    recipeLines: j['recipeLines'] as int,
    shoppingLines: j['shoppingLines'] as int,
    similar: [
      for (final s in (j['similar'] as List).cast<Map<String, dynamic>>())
        (
          id: s['id'] as int,
          name: s['name'] as String,
          category: s['category'] as String?,
        ),
    ],
  );

  @override
  Future<IngredientDetail> ingredientDetail(int id) => apiCall(
    () async => _detail(
      (await _dio.get<Map<String, dynamic>>('/owner/ingredients/$id')).data!,
    ),
  );

  @override
  Future<IngredientDetail> updateIngredient(
    int id, {
    String? name,
    String? category,
  }) => apiCall(
    () async => _detail(
      (await _dio.patch<Map<String, dynamic>>(
        '/owner/ingredients/$id',
        data: {'name': ?name, 'category': ?category},
      )).data!,
    ),
  );

  Future<Map<String, dynamic>> _aliasAction(
    int id,
    String action,
    String alias,
    bool preview,
  ) async => (await _dio.post<Map<String, dynamic>>(
    '/owner/ingredients/$id/aliases/$action',
    data: {'alias': alias, 'preview': preview},
  )).data!;

  static ({int lines, List<String> sample}) _preview(Map<String, dynamic> j) =>
      (lines: j['lines'] as int, sample: (j['sample'] as List).cast<String>());

  @override
  Future<({int lines, List<String> sample})> previewRemoveAlias(
    int id,
    String alias,
  ) => apiCall(
    () async => _preview(await _aliasAction(id, 'remove', alias, true)),
  );

  @override
  Future<int> removeAlias(int id, String alias) => apiCall(
    () async =>
        (await _aliasAction(id, 'remove', alias, false))['unlinked'] as int,
  );

  @override
  Future<({int lines, List<String> sample})> previewSplitAlias(
    int id,
    String alias,
  ) => apiCall(
    () async => _preview(await _aliasAction(id, 'split', alias, true)),
  );

  @override
  Future<({int id, String name, int moved})> splitAlias(int id, String alias) =>
      apiCall(() async {
        final j = await _aliasAction(id, 'split', alias, false);
        return (
          id: j['id'] as int,
          name: j['name'] as String,
          moved: j['moved'] as int,
        );
      });

  @override
  Future<int> addAlias(String ingredient, String alias) => apiCall(
    () async =>
        (await _alias(ingredient, alias, preview: false))['relinked'] as int,
  );

  @override
  Future<AiSettings> aiSettings() => apiCall(
    () async => aiSettingsFromJson(
      (await _dio.get<Map<String, dynamic>>('/owner/ai')).data!,
    ),
  );

  @override
  Future<AiSettings> saveAiSetting(String use, AiSetting setting) => apiCall(
    () async => aiSettingsFromJson(
      (await _dio.put<Map<String, dynamic>>(
        '/owner/ai/$use',
        data: {
          'provider': setting.provider,
          'model': setting.model,
          'reasoning': setting.reasoning,
        },
      )).data!,
    ),
  );

  @override
  Future<AiSettings> clearAiSetting(String use) => apiCall(
    () async => aiSettingsFromJson(
      (await _dio.delete<Map<String, dynamic>>('/owner/ai/$use')).data!,
    ),
  );

  @override
  Future<List<CatalogueSuggestion>> catalogueSuggestions() => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>(
      '/owner/catalogue/suggestions',
    )).data!;
    return [
      for (final s in (j['suggestions'] as List).cast<Map<String, dynamic>>())
        (
          name: s['name'] as String,
          ingredient: s['ingredient'] as String?,
          recipes: s['recipes'] as int,
          sample: s['sample'] as String,
        ),
    ];
  });

  @override
  Future<int> resolveSuggestion(String name, PickRef target) =>
      apiCall(() async {
        final j = (await _dio.post<Map<String, dynamic>>(
          '/owner/catalogue/suggestions/resolve',
          data: {
            'name': name,
            target.kind == 'brand' ? 'brandId' : 'productId': target.id,
          },
        )).data!;
        return j['linked'] as int;
      });

  @override
  Future<void> dismissSuggestion(String name) => apiCall(
    () => _dio.post<void>(
      '/owner/catalogue/suggestions/dismiss',
      data: {'name': name},
    ),
  );

  @override
  Future<({int saved, int linked})> addAliases(
    List<({String ingredient, String alias})> items,
  ) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/ingredients/aliases/batch',
      data: {
        'items': [
          for (final i in items) {'ingredient': i.ingredient, 'alias': i.alias},
        ],
      },
    )).data!;
    return (saved: j['saved'] as int, linked: j['relinked'] as int);
  });

  @override
  Future<ProductFill> fillProduct({
    String? barcode,
    String? url,
    String? name,
  }) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/catalogue/products/fill',
      data: barcode != null
          ? {'barcode': barcode}
          : url != null
          ? {'url': url}
          : {'name': name},
      options: Options(receiveTimeout: aiWait),
    )).data!;
    final m = j['maker'] as Map<String, dynamic>?;
    return (
      name: j['name'] as String,
      brand: j['brand'] as String?,
      brandIsNew: j['brandIsNew'] == true,
      size: (j['size'] as num?)?.toDouble(),
      unit: j['unit'] as String?,
      ingredient: j['ingredient'] as String?,
      aiIngredient: j['aiIngredient'] == true,
      source: j['source'] as String,
      maker: m == null
          ? null
          : (
              name: m['name'] as String,
              country: m['country'] as String?,
              source: m['source'] as String,
            ),
      similar: [
        for (final p
            in (j['similar'] as List? ?? const []).cast<Map<String, dynamic>>())
          _catalogueProduct(p),
      ],
      photo: j['photo'] as String?,
    );
  });

  @override
  Future<void> sendMessage({
    required String title,
    required String body,
    String? to,
    String kind = 'message',
    String? image,
  }) => apiCall(() async {
    final fields = {'title': title, 'body': body, 'to': to, 'kind': kind};
    await _dio.post<void>(
      '/owner/notifications',
      // With a photo: multipart, `to` empty = everyone.
      data: image == null
          ? fields
          : FormData.fromMap({
              ...fields,
              'to': to ?? '',
              'image': await MultipartFile.fromFile(
                image,
                contentType: DioMediaType(
                  'image',
                  'jpeg',
                ), // the editor writes JPEG
              ),
            }),
    );
  });

  @override
  Future<List<SentMessage>> sentMessages() => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>('/owner/notifications'))
        .data!;
    return [
      for (final m in (j['sent'] as List).cast<Map<String, dynamic>>())
        (
          id: m['id'] as int,
          title: m['title'] as String,
          body: m['body'] as String,
          to: m['to'] as String?,
          pushSent: m['pushSent'] as int,
          pushTotal: m['pushTotal'] as int,
          pending: m['pending'] as bool,
          kind: m['kind'] as String? ?? 'message', // a server before 2026-11
          image: m['image'] as String?,
          createdAt: dbTime(m['createdAt'] as String).toLocal(),
        ),
    ];
  });

  @override
  Future<void> deleteMessage(int id) =>
      apiCall(() => _dio.delete<void>('/owner/notifications/$id'));

  @override
  Future<GapSuggestion> suggestGap(String line) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/ingredients/gaps/suggest',
      data: {'line': line},
      options: Options(receiveTimeout: aiWait),
    )).data!;
    return (
      name: j['name'] as String?,
      ingredient: j['ingredient'] as String?,
      category: j['category'] as String?, // null from an older API
      types: [
        for (final t
            in (j['types'] as List? ?? const []).cast<Map<String, dynamic>>())
          (
            name: t['name'] as String,
            category: t['category'] as String?,
            ingredient: t['ingredient'] as String?,
          ),
      ],
    );
  });

  @override
  Future<({List<AliasSuggestion> items, int? next})> suggestAliases(
    int offset,
  ) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/ingredients/aliases/suggest',
      data: {'offset': offset},
      options: Options(receiveTimeout: aiWait),
    )).data!;
    return (
      items: [
        for (final i in (j['items'] as List).cast<Map<String, dynamic>>())
          (
            ingredient: i['ingredient'] as String,
            alias: i['alias'] as String,
            lines: i['lines'] as int,
          ),
      ],
      next: j['next'] as int?,
    );
  });

  @override
  Future<int> addIngredient(String name, String category) => apiCall(
    () async =>
        (await _dio.post<Map<String, dynamic>>(
              '/owner/ingredients',
              data: {'name': name, 'category': category},
            )).data!['relinked']
            as int,
  );

  @override
  Future<({int checked, int linked})> relinkIngredients() => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/owner/ingredients/relink',
    )).data!;
    return (checked: j['checked'] as int, linked: j['linked'] as int);
  });

  @override
  Future<({String ingredients, String aliases})> addedIngredientRows() =>
      apiCall(() async {
        final j = await _get('/owner/ingredients/added');
        return (
          ingredients: j['ingredients'] as String,
          aliases: j['aliases'] as String,
        );
      });

  Future<Map<String, dynamic>> _catalogue(
    String kind,
    String? query,
    int offset,
  ) => _get('/owner/catalogue/$kind', {
    if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    'offset': offset,
  });

  @override
  Future<CataloguePage<CatalogueMaker>> makers({
    String? query,
    int offset = 0,
  }) => apiCall(() async {
    final j = await _catalogue('makers', query, offset);
    return (
      items: [
        for (final m in (j['items'] as List).cast<Map<String, dynamic>>())
          CatalogueMaker(
            id: m['id'] as int,
            name: m['name'] as String,
            brands: m['brands'] as int,
          ),
      ],
      next: j['next'] as int?,
    );
  });

  @override
  Future<(CataloguePage<CatalogueBrand>, List<String>)> brands({
    String? query,
    int offset = 0,
  }) => apiCall(() async {
    final j = await _catalogue('brands', query, offset);
    return (
      (
        items: [
          for (final b in (j['items'] as List).cast<Map<String, dynamic>>())
            CatalogueBrand(
              id: b['id'] as int,
              name: b['name'] as String,
              makerId: b['makerId'] as int?,
              maker: b['maker'] as String?,
              country: b['country'] as String?,
              products: b['products'] as int,
            ),
        ],
        next: j['next'] as int?,
      ),
      (j['countries'] as List).cast<String>(),
    );
  });

  @override
  Future<(CataloguePage<CatalogueProduct>, List<String>)> products({
    String? query,
    int offset = 0,
  }) => apiCall(() async {
    final j = await _catalogue('products', query, offset);
    return (
      (
        items: [
          for (final p in (j['items'] as List).cast<Map<String, dynamic>>())
            _catalogueProduct(p),
        ],
        next: j['next'] as int?,
      ),
      (j['units'] as List).cast<String>(),
    );
  });

  /// The row's id.
  Future<int> _saveRow(String kind, int? id, Map<String, dynamic> body) =>
      apiCall(
        () async =>
            (await (id == null
                        ? _dio.post<Map<String, dynamic>>(
                            '/owner/catalogue/$kind',
                            data: body,
                          )
                        : _dio.patch<Map<String, dynamic>>(
                            '/owner/catalogue/$kind/$id',
                            data: body,
                          )))
                    .data!['id']
                as int,
      );

  @override
  Future<void> saveMaker({int? id, required String name}) =>
      _saveRow('makers', id, {'name': name});

  @override
  Future<void> saveBrand({
    int? id,
    required String name,
    int? makerId,
    String? country,
  }) => _saveRow('brands', id, {
    'name': name,
    'makerId': makerId,
    'country': country,
  });

  @override
  Future<int> saveProduct({
    int? id,
    required String name,
    String? ingredient,
    int? brandId,
    double? size,
    String? unit,
  }) => _saveRow('products', id, {
    'name': name,
    'ingredient': ingredient,
    'brandId': brandId,
    'size': size,
    'unit': unit,
  });

  @override
  Future<void> setProductPhoto(int id, {String? path, String? url}) => apiCall(
    () async => _dio.put<void>(
      '/owner/catalogue/products/$id/photo',
      data: path == null
          ? {'url': url}
          : FormData.fromMap({
              'image': await MultipartFile.fromFile(
                path,
                contentType: DioMediaType('image', 'jpeg'),
              ),
            }),
    ),
  );

  @override
  Future<void> removeProductPhoto(int id) =>
      apiCall(() => _dio.delete<void>('/owner/catalogue/products/$id/photo'));

  @override
  Future<void> deleteCatalogueRow(String kind, int id) =>
      apiCall(() => _dio.delete<void>('/owner/catalogue/$kind/$id'));

  @override
  Future<({String makers, String brands, String products})> catalogueRows() =>
      apiCall(() async {
        final j = await _get('/owner/catalogue/added');
        return (
          makers: j['makers'] as String,
          brands: j['brands'] as String,
          products: j['products'] as String,
        );
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

CatalogueProduct _catalogueProduct(Map<String, dynamic> p) => CatalogueProduct(
  id: p['id'] as int,
  name: p['name'] as String,
  ingredient: p['ingredient'] as String?,
  brandId: p['brandId'] as int?,
  brand: p['brand'] as String?,
  size: (p['size'] as num?)?.toDouble(),
  unit: p['unit'] as String?,
  photo: p['photo'] as String?,
);

AiSetting _aiSetting(Map<String, dynamic> j) => (
  provider: j['provider'] as String,
  model: j['model'] as String,
  reasoning: j['reasoning'] as String,
);

/// GET /owner/ai's body (also what PUT and DELETE return).
AiSettings aiSettingsFromJson(Map<String, dynamic> j) => (
  providers: [
    for (final p in (j['providers'] as List).cast<Map<String, dynamic>>())
      (
        id: p['id'] as String,
        name: p['name'] as String,
        configured: p['configured'] == true,
        models: [
          for (final m in (p['models'] as List).cast<Map<String, dynamic>>())
            (
              id: m['id'] as String,
              name: m['name'] as String,
              reasoning: (m['reasoning'] as List).cast<String>(),
              images: m['images'] == true,
            ),
        ],
      ),
  ],
  defaults: _aiSetting(j['default'] as Map<String, dynamic>),
  uses: [
    for (final u in (j['uses'] as List).cast<Map<String, dynamic>>())
      (
        id: u['id'] as String,
        budget: u['budget'] == true,
        images: u['images'] == true,
        setting: switch (u['setting']) {
          final Map<String, dynamic> s => _aiSetting(s),
          _ => null,
        },
      ),
  ],
);
