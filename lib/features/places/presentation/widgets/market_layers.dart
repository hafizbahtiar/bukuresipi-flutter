import 'package:maplibre_gl/maplibre_gl.dart';

import '../../domain/market.dart';

const marketSource = 'markets';
const marketFillLayer = 'markets-fill';
const marketLineLayer = 'markets-line';
const marketDotLayer = 'markets-dot';
const marketLayers = {marketFillLayer, marketLineLayer, marketDotLayer};

/// A market's dot, plus its street or ground when the server has a usable shape.
Map<String, dynamic> marketGeoJson(Iterable<Market> markets) => {
  'type': 'FeatureCollection',
  'features': [
    for (final m in markets) ...[
      if (m.shape case {'type': 'LineString' || 'Polygon'})
        {
          'type': 'Feature',
          'id': '${m.branchId}#shape',
          'geometry': m.shape,
          'properties': <String, dynamic>{},
        },
      {
        'type': 'Feature',
        'id': m.branchId,
        'geometry': {
          'type': 'Point',
          'coordinates': [m.lng, m.lat],
        },
        'properties': <String, dynamic>{},
      },
    ],
  ],
};

/// The market a tapped feature (its dot or its shape) belongs to.
String marketIdOf(String featureId) => featureId.split('#').first;

/// Added before the pins' layers, so a street or ground lies under them.
Future<void> addMarketLayers(MapLibreMapController map, String color) async {
  await map.addSource(
    marketSource,
    const GeojsonSourceProperties(
      data: {'type': 'FeatureCollection', 'features': []},
    ),
  );
  await map.addFillLayer(
    marketSource,
    marketFillLayer,
    FillLayerProperties(fillColor: color, fillOpacity: 0.22),
    filter: const [
      '==',
      ['geometry-type'],
      'Polygon',
    ],
  );
  await map.addLineLayer(
    marketSource,
    marketLineLayer,
    LineLayerProperties(
      lineColor: color,
      lineOpacity: 0.8,
      lineCap: 'round',
      lineJoin: 'round',
      lineWidth: const [
        'interpolate',
        ['linear'],
        ['zoom'],
        11,
        2,
        16,
        7,
      ],
    ),
    filter: const [
      '!=',
      ['geometry-type'],
      'Point',
    ],
  );
  await map.addCircleLayer(
    marketSource,
    marketDotLayer,
    CircleLayerProperties(
      circleColor: color,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2,
      circleRadius: const [
        'interpolate',
        ['linear'],
        ['zoom'],
        9,
        3,
        12,
        6,
      ],
    ),
    filter: const [
      '==',
      ['geometry-type'],
      'Point',
    ],
  );
}
