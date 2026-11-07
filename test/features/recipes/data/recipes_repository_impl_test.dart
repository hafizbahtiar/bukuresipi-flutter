import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:bukuresipi_flutter/features/recipes/data/recipes_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';
import '../recipes_fixtures.dart';

void main() {
  late FakeAdapter adapter;
  RecipesRepositoryImpl make((int, Object?) Function(RequestOptions) answer) {
    adapter = FakeAdapter(answer);
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokens: MemoryTokenStore(const Tokens(access: 'a', refresh: 'r')),
      appVersion: '1.0.0',
      adapter: adapter,
    );
    return RecipesRepositoryImpl(api.dio);
  }

  test(
    'list reads recipes newest first with counts and missing flags',
    () async {
      final older = {
        ...recipeJson,
        'id': 'r-0',
        'createdAt': '2026-11-01 08:00:00',
        'missing': ['steps'],
      };
      final repo = make(
        (_) => (
          200,
          {
            'items': [older, recipeJson],
          },
        ),
      );
      final recipes = await repo.list();
      expect(adapter.requests.single.path, '/recipes');
      expect(recipes.map((r) => r.id), ['r-1', 'r-0']);
      expect(recipes.map((r) => r.missing), [
        [],
        ['steps'],
      ]);
      expect(recipes.first.ingredientCount, 2);
      expect(recipes.first.stepCount, 2);
      expect(recipes.first.createdAt.isUtc, isTrue);
    },
  );

  test('one unreadable recipe does not take the list down', () async {
    final repo = make(
      (_) => (
        200,
        {
          'items': [
            recipeJson,
            {'id': 'broken'},
          ],
        },
      ),
    );
    expect((await repo.list()).map((r) => r.id), ['r-1']);
  });

  test('get reads the ingredients and steps', () async {
    final repo = make((_) => (200, recipeDetailJson));
    final detail = await repo.get('r-1');
    expect(adapter.requests.single.path, '/recipes/r-1');
    expect(detail.name, 'Nasi Lemak Ayam');
    expect(detail.ingredients.first.amount, '500 g');
    expect(detail.ingredients.first.label, 'Ayam');
    expect(detail.ingredients.last.label, 'sedikit bahan rahsia');
    expect(detail.steps.single.instruction, 'Goreng ayam hingga masak.');
  });

  test('delete removes the recipe', () async {
    final repo = make((_) => (204, null));
    await repo.delete('r-1');
    expect(
      [adapter.requests.single.method, adapter.requests.single.path],
      ['DELETE', '/recipes/r-1'],
    );
  });

  test('a missing recipe is an ApiException with its code', () async {
    final repo = make((_) => (404, {'error': 'not_found'}));
    await expectLater(
      repo.get('r-1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_found')),
    );
  });
}
