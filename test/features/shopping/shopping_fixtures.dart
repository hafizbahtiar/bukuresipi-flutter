import 'dart:async';

import 'package:bukuresipi_flutter/features/shopping/domain/shopping.dart';
import 'package:bukuresipi_flutter/features/shopping/domain/shopping_repository.dart';

/// In-memory list in the server's order: still to buy first, then bought.
class FakeShopping implements ShoppingRepository {
  List<ShoppingItem> items = [];
  final recipesAdded = <String>[];
  int _next = 0;

  List<ShoppingItem> get _sorted => [
    ...items.where((i) => !i.done),
    ...items.where((i) => i.done),
  ];

  final lists = <bool>[];

  /// When set, saves wait for it (the server is slow) and then throw [saveError] if that is set.
  Completer<void>? gate;
  Object? saveError;

  Future<void> _slow() async {
    await gate?.future;
    if (saveError != null) throw saveError!;
  }

  List<String> suggestions = const ['Gula pasir', 'Gula melaka'];

  @override
  Future<List<ShoppingItem>> list({bool family = false}) async {
    lists.add(family);
    return _sorted;
  }

  @override
  Future<List<String>> suggest(String query) async => suggestions
      .where((s) => s.toLowerCase().contains(query.toLowerCase()))
      .toList();

  @override
  Future<List<ShoppingItem>> addText(String text, {bool family = false}) async {
    await _slow();
    final item = ShoppingItem(id: 'i${_next++}', text: text, done: false);
    items = [...items, item];
    return [item];
  }

  final skippedOptional = <bool>[];
  @override
  Future<List<ShoppingItem>> addRecipe(
    String recipeId, {
    bool family = false,
    bool skipOptional = false,
  }) async {
    recipesAdded.add(recipeId);
    skippedOptional.add(skipOptional);
    if (items.any((i) => i.recipes.any((r) => r.id == recipeId))) return [];
    final item = ShoppingItem(
      id: 'i${_next++}',
      text: '2 cawan beras putih',
      done: false,
      ingredient: 'Beras putih',
      recipes: [(id: recipeId, name: 'Nasi Lemak Ayam')],
      products: const [
        ShoppingProduct(
          name: 'Beras Super Special Tempatan Jati 5kg',
          brand: 'Jati',
        ),
      ],
    );
    items = [...items, item];
    return [item];
  }

  @override
  Future<ShoppingItem> setDone(String id, bool done) async {
    await _slow();
    final old = items.firstWhere((i) => i.id == id);
    final item = ShoppingItem(
      id: id,
      text: old.text,
      done: done,
      ingredient: old.ingredient,
      recipes: old.recipes,
      products: old.products,
    );
    items = [for (final i in items) i.id == id ? item : i];
    return item;
  }

  @override
  Future<void> delete(String id) async {
    await _slow();
    items = items.where((i) => i.id != id).toList();
  }

  @override
  Future<void> clearDone({bool family = false}) async =>
      items = items.where((i) => !i.done).toList();

  @override
  Future<List<ShoppingProduct>> products(String ingredient) async => const [
    ShoppingProduct(
      name: 'Beras Super Special Tempatan Jati 5kg',
      brand: 'Jati',
      manufacturer: 'Serba Wangi Sdn Bhd',
    ),
    ShoppingProduct(
      name: 'Jati Signature Super Special Rice 10kg',
      brand: 'Jati',
    ),
  ];
}
