import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../places_fixtures.dart';

void main() {
  test('load fills the list; a failed load keeps what was there and shows the error', () async {
    final repo = FakePlaces()
      ..places = [place(id: 'a'), place(id: 'b', lat: null)];
    final c = PlacesController(repo);
    await c.load();
    expect(c.places.map((p) => p.id), ['a', 'b']);
    expect(c.pinned.map((p) => p.id), ['a']);
    expect(c.unpinned.map((p) => p.id), ['b']);
    repo.error = const ApiException(ApiException.network);
    await c.load();
    expect(c.places, hasLength(2));
    expect(c.error, ApiException.network);
    expect(c.loading, isFalse);
  });

  test('remove takes the place off the list after the API agrees', () async {
    final repo = FakePlaces()..places = [place(id: 'a'), place(id: 'b')];
    final c = PlacesController(repo);
    await c.load();
    await c.remove('a');
    expect(repo.removed, ['a']);
    expect(c.places.map((p) => p.id), ['b']);
  });

  test('a note change is saved and shown', () async {
    final repo = FakePlaces()..places = [place(id: 'a')];
    final c = PlacesController(repo);
    await c.load();
    await c.updateNote('a', 'Order the ayam goreng');
    expect(repo.notes, {'a': 'Order the ayam goreng'});
    expect(c.byId('a')?.note, 'Order the ayam goreng');
  });

  test('clear forgets the last user\'s places (sign-out)', () async {
    final c = PlacesController(FakePlaces()..places = [place(id: 'a')]);
    await c.load();
    c.clear();
    expect(c.places, isEmpty);
    expect(c.loaded, isFalse);
  });

  test(
    'setting a pin, finding a location or deleting a branch reloads the places',
    () async {
      final repo = FakePlaces()..places = [place(id: 'a', lat: null)];
      final c = PlacesController(repo);
      await c.load();
      repo.places = [place(id: 'a')];
      await c.setPin('b-1', 3.1, 101.7);
      expect(c.pinned.map((p) => p.id), ['a']);
      expect(await c.locate('b-1'), isTrue);
      repo.places = [];
      await c.deleteBranch('b-1');
      expect(c.places, isEmpty);
      expect(
        [repo.pins.single.$1, repo.located.single, repo.deletedBranches.single],
        ['b-1', 'b-1', 'b-1'],
      );
    },
  );
}
