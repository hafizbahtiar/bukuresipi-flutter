import 'dart:async';

import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/shopping/domain/shopping.dart';
import 'package:bukuresipi_flutter/features/shopping/presentation/shopping_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shopping_fixtures.dart';

void main() {
  late FakeShopping repo;
  late ShoppingController shopping;
  List<(String, bool)> shown() => [
    for (final i in shopping.items) (i.text, i.done),
  ];

  setUp(() async {
    repo = FakeShopping()
      ..items = const [
        ShoppingItem(id: 'a', text: 'Gula', done: false),
        ShoppingItem(id: 'b', text: 'Garam', done: false),
      ];
    shopping = ShoppingController(repo);
    await shopping.load();
  });

  test(
    'a tick shows before the server answers; two quick ticks both stay',
    () async {
      repo.gate = Completer();
      final first = shopping.setDone('a', true);
      final second = shopping.setDone('b', true);
      expect(shown(), [('Gula', true), ('Garam', true)]); // at once, in place
      repo.gate!.complete();
      await Future.wait([first, second]);
      await pumpEventQueue(); // the quiet reload after the last save
      expect(shown(), [('Gula', true), ('Garam', true)]);
    },
  );

  test('a failed save puts that change back and throws', () async {
    repo
      ..gate = Completer()
      ..saveError = const ApiException('network');
    final remove = shopping.remove('a');
    expect(shown(), [('Garam', false)]);
    repo.gate!.complete();
    await expectLater(remove, throwsA(isA<ApiException>()));
    expect(shown(), [('Gula', false), ('Garam', false)]);
  });

  test('a typed line shows at once (not saved yet), then takes the server id and keeps its row key', () async {
    repo.gate = Completer();
    final add = shopping.addText('Telur');
    final local = shopping.items.last;
    expect([local.text, shopping.isLocal(local)], ['Telur', true]);
    final key = shopping.keyOf(local);
    repo.gate!.complete();
    await add;
    final saved = shopping.items.firstWhere((i) => i.text == 'Telur');
    expect(shopping.isLocal(saved), isFalse);
    expect(shopping.keyOf(saved), key);
  });
}
