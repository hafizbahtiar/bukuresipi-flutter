/// The two kinds of place that are weekly markets (the server's MARKET_KINDS).
const marketKinds = {'pasar_malam', 'pasar_tani'};

/// The clock markets run on, whatever time zone the phone is set to.
DateTime malaysiaNow([DateTime? at]) =>
    (at ?? DateTime.now()).toUtc().add(const Duration(hours: 8));

/// One weekly opening. [day] is ISO (1 = Monday ... 7 = Sunday); [opens]/[closes] are "HH:MM", Malaysia time.
class MarketDay {
  const MarketDay({
    required this.day,
    required this.opens,
    required this.closes,
  });

  factory MarketDay.fromJson(Map<String, dynamic> j) => MarketDay(
    day: (j['day'] as num).toInt(),
    opens: j['opens'] as String,
    closes: j['closes'] as String,
  );

  final int day;
  final String opens, closes;

  Map<String, dynamic> toJson() => {
    'day': day,
    'opens': opens,
    'closes': closes,
  };

  int get opensAt => _minutes(opens);
  int get closesAt => _minutes(closes);

  /// Closes at or before it opens: the night runs past midnight.
  bool get overnight => closesAt <= opensAt;

  static int _minutes(String hhmm) {
    final [h, m] = hhmm.split(':').map(int.parse).toList();
    return h * 60 + m;
  }
}

/// An opening that still matters today: [openNow], or later today. [breakNow] = closed between two of today's
/// openings (a shop's lunch or rest break: "Rehat until 5 pm").
typedef MarketToday = ({MarketDay slot, bool openNow, bool breakNow});

/// What is left of today at [now] (Malaysia time). Last night's opening still running counts. null = nothing more
/// today, or days not known: never "closed".
MarketToday? marketToday(List<MarketDay> schedule, DateTime now) {
  final minute = now.hour * 60 + now.minute;
  final yesterday = now.weekday == 1 ? 7 : now.weekday - 1;
  MarketDay? later;
  var endedToday = false;
  for (final s in schedule) {
    if (s.day == yesterday && s.overnight && minute < s.closesAt) {
      return (slot: s, openNow: true, breakNow: false);
    }
    if (s.day != now.weekday) continue;
    final end = s.overnight ? s.closesAt + 24 * 60 : s.closesAt;
    if (minute >= s.opensAt && minute < end) {
      return (slot: s, openNow: true, breakNow: false);
    }
    if (minute >= end) endedToday = true;
    if (minute < s.opensAt && (later == null || s.opensAt < later.opensAt)) {
      later = s;
    }
  }
  return later == null
      ? null
      : (slot: later, openNow: false, breakNow: endedToday);
}

/// The markets still on today: open now first, then nearest.
List<({Market market, MarketToday today})> marketsOnToday(
  Iterable<Market> markets,
  DateTime now,
) {
  final on = [
    for (final m in markets)
      if (marketToday(m.schedule, now) case final today?)
        (market: m, today: today),
  ];
  on.sort((a, b) {
    if (a.today.openNow != b.today.openNow) return a.today.openNow ? -1 : 1;
    return a.market.distanceM.compareTo(b.market.distanceM);
  });
  return on;
}

/// A pasar malam or pasar tani near a point (GET /places/markets).
class Market {
  const Market({
    required this.placeId,
    required this.branchId,
    required this.name,
    this.label,
    required this.subcategory,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.schedule = const [],
    this.shape,
    this.savedPlaceId,
  });

  factory Market.fromJson(Map<String, dynamic> j) => Market(
    placeId: j['placeId'] as String,
    branchId: j['branchId'] as String,
    name: j['name'] as String,
    label: j['label'] as String?,
    subcategory: j['subcategory'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    distanceM: (j['distanceM'] as num).toInt(),
    schedule: [
      for (final s in (j['schedule'] as List).cast<Map<String, dynamic>>())
        MarketDay.fromJson(s),
    ],
    shape: j['shape'] as Map<String, dynamic>?,
    savedPlaceId: j['savedPlaceId'] as String?,
  );

  final String placeId, branchId, name, subcategory;
  final String? label;
  final double lat, lng;

  /// From the point asked about (Home: the phone).
  final int distanceM;

  /// [] = days not known yet.
  final List<MarketDay> schedule;

  /// GeoJSON LineString or Polygon to draw; null = a point.
  final Map<String, dynamic>? shape;

  /// The caller's save of this place; null = not in their book.
  final String? savedPlaceId;

  Market copyWith({String? savedPlaceId}) => Market(
    placeId: placeId,
    branchId: branchId,
    name: name,
    label: label,
    subcategory: subcategory,
    lat: lat,
    lng: lng,
    distanceM: distanceM,
    schedule: schedule,
    shape: shape,
    savedPlaceId: savedPlaceId ?? this.savedPlaceId,
  );
}
