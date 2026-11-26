import 'package:bukuresipi_flutter/core/network/api_client.dart';
import 'package:bukuresipi_flutter/core/storage/token_store.dart';
import 'package:bukuresipi_flutter/features/shopping/data/shopping_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';

void main() {
  test("a line's pick is read", () async {
    final api = ApiClient(
      baseUrl: 'https://api.test',
      tokens: MemoryTokenStore(const Tokens(access: 'a', refresh: 'r')),
      appVersion: '1.0.0',
      adapter: FakeAdapter(
        (_) => (
          200,
          {
            'items': [
              {
                'id': 's-1',
                'text': '200 ml santan',
                'done': false,
                'pick': {
                  'kind': 'brand',
                  'id': 3,
                  'name': 'Kara',
                  'brand': 'Kara',
                  'avoided': false,
                },
              },
              {'id': 's-2', 'text': 'garam', 'done': false, 'pick': null},
            ],
          },
        ),
      ),
    );
    final items = await ShoppingRepositoryImpl(api.dio).list();
    expect(items.first.pick?.name, 'Kara');
    expect(items.last.pick, isNull);
  });
}
