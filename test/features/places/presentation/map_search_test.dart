import 'package:bukuresipi_flutter/features/places/presentation/widgets/map_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../places_fixtures.dart';

void main() {
  test('map search finds pinned branches by name or label, any case, and skips unpinned ones', () {
    final places = [
      place(id: 'p-1', name: 'Nasi Kandar Pelita'),
      place(id: 'p-2', name: 'Kopi Tiam'),
      place(id: 'p-3', name: 'Nasi Lemak Unpinned', lat: null),
    ];
    expect(searchPins(places, '  NASI ').map((h) => h.$1.id), ['p-1']);
    expect(searchPins(places, 'tiam ampang').map((h) => h.$1.id), ['p-2']);
    expect(searchPins(places, ''), isEmpty);
    expect(searchPins(places, 'sushi'), isEmpty);
  });
}
