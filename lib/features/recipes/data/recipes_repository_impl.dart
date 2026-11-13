import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/log.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/disk_image_cache.dart';
import '../../../core/network/db_time.dart';
import '../domain/recipe_variant.dart';
import '../domain/recipe.dart';
import '../domain/recipes_repository.dart';

class RecipesRepositoryImpl implements RecipesRepository {
  RecipesRepositoryImpl(this._dio);

  final Dio _dio;

  static const _coverTypes = {
    'jpg': 'jpeg',
    'jpeg': 'jpeg',
    'png': 'png',
    'webp': 'webp',
  };
  static const _maxCoverBytes = 5 * 1024 * 1024;

  @override
  Future<RecipeDetail> setCover(String id, String path) async {
    final subtype = _coverTypes[path.split('.').last.toLowerCase()];
    if (subtype == null || await File(path).length() > _maxCoverBytes) {
      throw const ApiException('invalid_image');
    }
    return apiCall(() async {
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          path,
          contentType: DioMediaType('image', subtype),
        ),
      });
      return recipeDetailFromJson(
        (await _dio.put<Map<String, dynamic>>(
          '/recipes/$id/cover',
          data: form,
        )).data!,
      );
    });
  }

  @override
  Future<void> removeCover(String id) =>
      apiCall(() => _dio.delete<void>('/recipes/$id/cover'));

  // Keyed by cover id: a new upload is a new key, so nothing stale is ever shown.
  final _covers = <String, Future<Uint8List?>>{};

  @override
  Future<Uint8List?> cover(String id, String cover) {
    // shortcut: FIFO, not LRU; fine for one book of recipes.
    if (_covers.length >= 80) _covers.remove(_covers.keys.first);
    return _covers['$id/$cover'] ??=
        diskCached(
          'cover-$cover',
          () => apiCall(() async {
            // Through Dio, not Image.network: the request needs the token (and its refresh); R2 is private.
            final res = await _dio.get<List<int>>(
              '/recipes/$id/cover',
              options: Options(
                responseType: ResponseType.bytes,
                validateStatus: (s) => s == 200 || s == 404,
              ),
            );
            return res.statusCode == 200 ? Uint8List.fromList(res.data!) : null;
          }),
        )..catchError((Object _) {
          _covers.remove(
            '$id/$cover',
          ); // a failed fetch is tried again next time
          return null;
        });
  }

  @override
  Future<List<Recipe>> list({bool family = false}) => apiCall(() async {
    // shortcut: the book reads every page up front (50 each); page it on scroll when books get long.
    final rows = <dynamic>[];
    String? cursor;
    do {
      final data = (await _dio.get<Map<String, dynamic>>(
        '/recipes',
        queryParameters: {
          'limit': 50,
          if (family) 'scope': 'family',
          'cursor': ?cursor,
        },
      )).data!;
      rows.addAll(data['items'] as List);
      cursor = data['next'] as String?;
    } while (cursor != null);
    final recipes = <Recipe>[];
    for (final j in rows) {
      try {
        recipes.add(recipeFromJson(j as Map<String, dynamic>));
      } catch (e) {
        log('recipes: skipped row: $e; row=${logJson(j)}');
      }
    }
    log('recipes: ${recipes.length}/${rows.length} rows loaded');
    return recipes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<({List<Recipe> recipes, String? next})> community({
    String? query,
    String? cursor,
    int? limit,
  }) => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>(
      '/recipes/community',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'cursor': ?cursor,
        'limit': ?limit,
      },
    )).data!;
    return (
      recipes: [
        for (final j in (data['items'] as List).cast<Map<String, dynamic>>())
          recipeFromJson(j),
      ],
      next: data['next'] as String?,
    );
  });

  @override
  Future<({List<Dish> dishes, String? next})> dishes({
    String? query,
    String? cursor,
    int? limit,
  }) => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>(
      '/catalogue/dishes',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'cursor': ?cursor,
        'limit': ?limit,
      },
    )).data!;
    return (
      dishes: [
        for (final d in (data['items'] as List).cast<Map<String, dynamic>>())
          Dish(
            id: d['id'] as String,
            name: d['name'] as String,
            category: d['category'] as String?,
            ingredientCount: (d['ingredientCount'] as num?)?.toInt() ?? 0,
            cover: d['cover'] as String?,
          ),
      ],
      next: data['next'] as String?,
    );
  });

  @override
  Future<RecipeDetail> copy(String id) => apiCall(
    () async => recipeDetailFromJson(
      (await _dio.post<Map<String, dynamic>>('/recipes/$id/copy')).data!,
    ),
  );

  @override
  Future<RecipeDetail> setVisibility(String id, RecipeVisibility visibility) =>
      apiCall(
        () async => recipeDetailFromJson(
          (await _dio.patch<Map<String, dynamic>>(
            '/recipes/$id',
            data: {'visibility': visibility.name},
          )).data!,
        ),
      );

  @override
  Future<void> report(String id, String reason, {String? note}) => apiCall(
    () => _dio.post<void>(
      '/recipes/$id/report',
      data: {'reason': reason, 'note': ?note},
    ),
  );

  @override
  Future<RecipeDetail> get(String id) => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>('/recipes/$id')).data!;
    return recipeDetailFromJson(data);
  });

  @override
  Future<List<RecipeVariant>> variants(String id) => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>('/recipes/$id/variants'))
        .data!;
    return [
      for (final v in (data['variants'] as List).cast<Map<String, dynamic>>())
        recipeVariantFromJson(v),
    ];
  });

  @override
  Future<void> delete(String id) =>
      apiCall(() => _dio.delete<void>('/recipes/$id'));

  @override
  Future<List<String>> searchIngredients(String query) => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>(
      '/recipes/ingredients',
      queryParameters: {'q': query},
    )).data!;
    return [
      for (final i
          in (data['ingredients'] as List).cast<Map<String, dynamic>>())
        i['name'] as String,
    ];
  });

  @override
  Future<RecipeDetail> setIngredientOptional(
    String id,
    int index,
    bool optional,
  ) => apiCall(() async {
    final data = (await _dio.put<Map<String, dynamic>>(
      '/recipes/$id/ingredients/$index',
      data: {'optional': optional},
    )).data!;
    return recipeDetailFromJson(data);
  });

  @override
  Future<RecipeDetail> linkIngredient(String id, int index, String? name) =>
      apiCall(() async {
        final data = (await _dio.put<Map<String, dynamic>>(
          '/recipes/$id/ingredients/$index',
          data: {'ingredient': name},
        )).data!;
        return recipeDetailFromJson(data);
      });

  @override
  Future<RecipeDetail> create({
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  }) => apiCall(() async {
    final data = (await _dio.post<Map<String, dynamic>>(
      '/recipes',
      data: {'name': name, 'ingredients': ingredients, 'steps': steps},
    )).data!;
    return recipeDetailFromJson(data);
  });

  @override
  Future<RecipeDetail> edit(
    String id, {
    required String name,
    required List<String> ingredients,
    required List<String> steps,
  }) => apiCall(() async {
    final data = (await _dio.patch<Map<String, dynamic>>(
      '/recipes/$id',
      data: {'name': name, 'ingredients': ingredients, 'steps': steps},
    )).data!;
    return recipeDetailFromJson(data);
  });
}

List<String> _missing(Object? v) => [
  ...((v as List?) ?? const []).cast<String>(),
];

RecipeOwner? _owner(Object? o) => o is Map<String, dynamic>
    ? RecipeOwner(name: o['name'] as String?, isMe: o['isMe'] as bool? ?? false)
    : null;

Recipe recipeFromJson(Map<String, dynamic> j) => Recipe(
  id: j['id'] as String,
  name: j['name'] as String,
  visibility: RecipeVisibility.parse(j['visibility']),
  owner: _owner(j['owner']),
  createdAt: dbTime(j['createdAt'] as String),
  sourceUrl: j['sourceUrl'] as String?,
  missing: _missing(j['missing']),
  ingredientCount: (j['ingredientCount'] as num?)?.toInt() ?? 0,
  stepCount: (j['stepCount'] as num?)?.toInt() ?? 0,
  shareId: j['shareId'] as String?,
  cover: j['cover'] as String?,
);

RecipeDetail recipeDetailFromJson(Map<String, dynamic> j) => RecipeDetail(
  id: j['id'] as String,
  name: j['name'] as String,
  visibility: RecipeVisibility.parse(j['visibility']),
  owner: _owner(j['owner']),
  canEdit: j['canEdit'] as bool? ?? true,
  hidden: j['hidden'] as bool? ?? false,
  sourceType:
      RecipeSourceType.values
          .where((t) => t.name == (j['source'] as Map?)?['type'])
          .firstOrNull ??
      (j['sourceUrl'] != null ? RecipeSourceType.link : RecipeSourceType.typed),
  platform: (j['source'] as Map?)?['platform'] as String?,
  createdAt: dbTime(j['createdAt'] as String),
  sourceUrl: j['sourceUrl'] as String?,
  shareId: j['shareId'] as String?,
  cover: j['cover'] as String?,
  missing: _missing(j['missing']),
  ingredients: [
    for (final i
        in (j['ingredients'] as List? ?? const []).cast<Map<String, dynamic>>())
      RecipeIngredient(
        name: i['name'] as String?,
        rawText: i['rawText'] as String?,
        quantity: i['quantity'] as String?,
        unit: i['unit'] as String?,
        optional: i['optional'] == true,
      ),
  ],
  steps: [
    for (final s
        in (j['steps'] as List? ?? const []).cast<Map<String, dynamic>>())
      RecipeStep(
        stepNo: (s['stepNo'] as num).toInt(),
        instruction: s['instruction'] as String,
      ),
  ],
  allergens: [
    for (final a
        in (j['allergens'] as List? ?? const []).cast<Map<String, dynamic>>())
      RecipeAllergen(
        name: a['name'] as String,
        ingredients: (a['ingredients'] as List).cast<String>(),
        optionalOnly: a['optionalOnly'] == true,
      ),
  ],
  uncheckedIngredients: (j['uncheckedIngredients'] as num?)?.toInt() ?? 0,
);
