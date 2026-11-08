import 'dart:async';

import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../places_fixtures.dart';

void main() {
  _signOutDuringLoad();
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
    await c.updateNote('a', '  ');
    expect(c.byId('a')?.note, isNull);
  });

  test(
    'nearby passes the point through; saveBranch saves then reloads',
    () async {
      final repo = FakePlaces()..nearbyResults = [nearbyBranch()];
      final c = PlacesController(repo);
      await c.load();
      final rows = await c.nearby(3.15, 101.71, 5);
      expect(rows.single.branchId, 'b-1');
      expect(repo.nearbyCalls.single, (3.15, 101.71, 5.0));

      repo.places = [place(id: 'p')];
      repo.saveBranchResult = place(id: 'p');
      final saved = await c.saveBranch('b-1');
      expect(saved.id, 'p');
      expect(repo.savedBranches, ['b-1']);
      expect(c.places.map((p) => p.id), ['p']);
    },
  );

  test('setRating replaces the branch summary without a full reload', () async {
    final repo = FakePlaces()..places = [place(id: 'a')];
    final c = PlacesController(repo);
    await c.load();
    repo.ratingResult = const RatingSummary(
      average: 4.3,
      count: 7,
      mine: 4,
      canRate: true,
    );

    final rating = await c.setRating('b-1', 4);
    expect(repo.ratingCalls, [('b-1', 4)]);
    expect(rating.mine, 4);
    expect(c.byId('a')!.branches.single.rating.mine, 4);

    await c.setRating('b-1', null);
    expect(repo.ratingCalls.last, ('b-1', null));
  });

  test('owner branch edit saves then reloads the places', () async {
    final repo = FakePlaces()..places = [place(id: 'a')];
    final c = PlacesController(repo);
    await c.load();
    repo.places = [place(id: 'a', name: 'Kedai Baru')];
    await c.updateBranch('b-1', label: 'Kedai Baru', lat: 2.99, lng: 101.79);
    expect(repo.branchUpdates.single.id, 'b-1');
    expect(repo.branchUpdates.single.label, 'Kedai Baru');
    expect(repo.branchUpdates.single.lat, 2.99);
    expect(c.places.single.restaurant.name, 'Kedai Baru');
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
      expect(await c.locate('b-1'), LocateResult.found);
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

class _SlowPlaces extends FakePlaces {
  final pending = <Completer<List<Place>>>[];

  @override
  Future<List<Place>> list() {
    pending.add(Completer());
    return pending.last.future;
  }
}

void _signOutDuringLoad() {
  test(
    'sign-out during a load: the old answer is dropped and the next user loads',
    () async {
      final repo = _SlowPlaces();
      final c = PlacesController(repo);
      final old = c.load();
      c.clear(); // signed out while the request is in flight
      final next = c.load(); // the next user signs in
      expect(repo.pending, hasLength(2));
      repo.pending[0].complete([place(id: 'old-user')]);
      await old;
      expect(c.places, isEmpty);
      repo.pending[1].complete([place(id: 'new-user')]);
      await next;
      expect(c.places.map((p) => p.id), ['new-user']);
    },
  );
}
