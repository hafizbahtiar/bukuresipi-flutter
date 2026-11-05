import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/shopping.dart';
import '../domain/shopping_repository.dart';

class ShoppingRepositoryImpl implements ShoppingRepository {
  ShoppingRepositoryImpl(this._dio);

  final Dio _dio;

  Future<List<ShoppingItem>> _items(
    Future<Response<Map<String, dynamic>>> req,
  ) async => [
    for (final j
        in ((await req).data!['items'] as List).cast<Map<String, dynamic>>())
      shoppingItemFromJson(j),
  ];

  @override
  Future<List<ShoppingItem>> list() =>
      apiCall(() => _items(_dio.get<Map<String, dynamic>>('/shopping')));

  @override
  Future<List<ShoppingItem>> addText(String text) => apiCall(
    () => _items(
      _dio.post<Map<String, dynamic>>('/shopping', data: {'text': text}),
    ),
  );

  @override
  Future<List<ShoppingItem>> addRecipe(String recipeId) => apiCall(
    () => _items(
      _dio.post<Map<String, dynamic>>(
        '/shopping',
        data: {'recipeId': recipeId},
      ),
    ),
  );

  @override
  Future<ShoppingItem> setDone(String id, bool done) => apiCall(
    () async => shoppingItemFromJson(
      (await _dio.patch<Map<String, dynamic>>(
        '/shopping/$id',
        data: {'done': done},
      )).data!,
    ),
  );

  @override
  Future<void> delete(String id) =>
      apiCall(() => _dio.delete<void>('/shopping/$id'));

  @override
  Future<List<ShoppingProduct>> products(String ingredient) => apiCall(
    () async {
      final data = (await _dio.get<Map<String, dynamic>>(
        '/catalogue/products',
        queryParameters: {'ingredient': ingredient},
      )).data!;
      return [
        for (final p in (data['products'] as List).cast<Map<String, dynamic>>())
          _product(p),
      ];
    },
  );

  @override
  Future<void> clearDone() =>
      apiCall(() => _dio.delete<void>('/shopping/done'));
}

ShoppingItem shoppingItemFromJson(Map<String, dynamic> j) {
  return ShoppingItem(
    id: j['id'] as String,
    text: j['text'] as String,
    done: j['done'] as bool,
    ingredient: j['ingredient'] as String?,
    recipes: [
      for (final r
          in (j['recipes'] as List? ?? const []).cast<Map<String, dynamic>>())
        (id: r['id'] as String, name: r['name'] as String),
    ],
    products: [
      for (final p
          in (j['products'] as List? ?? const []).cast<Map<String, dynamic>>())
        _product(p),
    ],
  );
}

ShoppingProduct _product(Map<String, dynamic> p) => ShoppingProduct(
  name: p['name'] as String,
  brand: p['brand'] as String?,
  manufacturer: p['manufacturer'] as String?,
);
