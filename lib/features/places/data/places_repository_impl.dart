import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/log.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/db_time.dart';
import '../domain/nearby_branch.dart';
import '../domain/place.dart';
import '../domain/places_repository.dart';
import '../domain/rating.dart';
import '../domain/report.dart';
import '../domain/review.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  PlacesRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Place>> list() => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>('/places')).data!;
    final rows = data['places'] as List;
    final places = <Place>[];
    for (final j in rows) {
      try {
        places.add(placeFromJson(j as Map<String, dynamic>));
      } catch (e) {
        log('places: skipped row: $e; row=${logJson(j)}');
      }
    }
    log('places: ${places.length}/${rows.length} rows loaded');
    return places..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<void> updateNote(String id, String? note) => apiCall(() async {
    final trimmed = note?.trim();
    await _dio.patch<void>(
      '/places/$id',
      data: {'note': trimmed == null || trimmed.isEmpty ? null : trimmed},
    );
  });

  @override
  Future<void> setPrivate(String id, bool private) => apiCall(
    () => _dio.patch<void>('/places/$id', data: {'private': private}),
  );

  @override
  Future<void> setPin(String branchId, double lat, double lng) => apiCall(
    () => _dio.put<void>(
      '/places/branches/$branchId/pin',
      data: {'lat': lat, 'lng': lng},
    ),
  );

  @override
  Future<LocateResult> locate(String branchId) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/places/branches/$branchId/locate',
      // The server may search the web and ask the AI: longer than the usual 30 s.
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    return switch (res.data!['result']) {
      'tried_today' => LocateResult.triedToday,
      _ when res.data!['found'] == true => LocateResult.found,
      _ => LocateResult.notFound,
    };
  });

  @override
  Future<({int merged, int removed})> tidyBranches(String restaurantId) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/places/restaurants/$restaurantId/tidy',
          // Clef compares the branches one by one on the server.
          options: Options(receiveTimeout: const Duration(seconds: 90)),
        );
        return (
          merged: res.data!['merged'] as int,
          removed: res.data!['removed'] as int,
        );
      });

  @override
  Future<void> deleteBranch(String branchId) =>
      apiCall(() => _dio.delete<void>('/places/branches/$branchId'));

  @override
  Future<void> updateBranch(
    String branchId, {
    String? label,
    String? address,
    String? city,
    String? state,
    double? lat,
    double? lng,
    BranchEditScope scope = BranchEditScope.personal,
  }) => apiCall(
    () => _dio.patch<void>(
      '/places/branches/$branchId',
      data: {
        'label': label,
        'address': address,
        'city': city,
        'state': state,
        'lat': ?lat,
        'lng': ?lng,
        'scope': scope == BranchEditScope.shared ? 'owner' : 'self',
      },
    ),
  );

  @override
  Future<BranchSuggestion> suggestBranch(String branchId) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/places/branches/$branchId/suggest',
      // Geocoding + the AI can take longer than the usual 30 s.
      options: Options(receiveTimeout: const Duration(seconds: 120)),
    )).data!;
    final d = j['draft'] as Map<String, dynamic>;
    return BranchSuggestion(
      draft: BranchDraft(
        label: d['label'] as String?,
        address: d['address'] as String?,
        city: d['city'] as String?,
        state: d['state'] as String?,
        lat: (d['lat'] as num?)?.toDouble(),
        lng: (d['lng'] as num?)?.toDouble(),
      ),
      sources: ((j['sources'] as List?) ?? const []).cast<String>(),
      aiUsed: j['aiUsed'] as bool? ?? false,
      changed: j['changed'] as bool? ?? false,
      summary: j['summary'] as String?,
      warnings: ((j['warnings'] as List?) ?? const []).cast<String>(),
      candidates: [
        for (final c
            in ((j['candidates'] as List?) ?? const [])
                .cast<Map<String, dynamic>>())
          (
            source: c['source'] as String,
            lat: (c['lat'] as num).toDouble(),
            lng: (c['lng'] as num).toDouble(),
            address: c['address'] as String?,
            fromDraftM: (c['fromDraftM'] as num?)?.round(),
          ),
      ],
    );
  });

  @override
  Future<({String query, List<PinHit> hits})> searchPin(
    String branchId,
    String source, {
    String? q,
  }) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/places/branches/$branchId/search-pin',
      data: {'source': source, 'q': ?q},
    )).data!;
    return (
      query: j['query'] as String,
      hits: [
        for (final h in (j['hits'] as List).cast<Map<String, dynamic>>())
          (
            lat: (h['lat'] as num).toDouble(),
            lng: (h['lng'] as num).toDouble(),
            address: h['address'] as String,
            city: h['city'] as String?,
            state: h['state'] as String?,
            source: h['source'] as String,
          ),
      ],
    );
  });

  @override
  Future<MapsPin> pinFromMapsLink(String url) => apiCall(() async {
    final j = (await _dio.post<Map<String, dynamic>>(
      '/places/maps-link',
      data: {'url': url},
    )).data!;
    return (
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      name: j['name'] as String?,
    );
  });

  @override
  Future<void> remove(String id) =>
      apiCall(() => _dio.delete<void>('/places/$id'));

  @override
  Future<List<NearbyBranch>> nearby(double lat, double lng, double km) =>
      apiCall(() async {
        final data = (await _dio.get<Map<String, dynamic>>(
          '/places/nearby',
          queryParameters: {'lat': lat, 'lng': lng, 'km': km},
        )).data!;
        return [
          for (final j
              in (data['branches'] as List).cast<Map<String, dynamic>>())
            nearbyBranchFromJson(j),
        ];
      });

  @override
  Future<RatingSummary> rateBranch(String branchId, int stars) =>
      apiCall(() async {
        final data = (await _dio.put<Map<String, dynamic>>(
          '/places/branches/$branchId/rating',
          data: {'stars': stars},
        )).data!;
        return ratingFromJson(data['rating']);
      });

  @override
  Future<RatingSummary> clearRating(String branchId) => apiCall(() async {
    final data = (await _dio.delete<Map<String, dynamic>>(
      '/places/branches/$branchId/rating',
    )).data!;
    return ratingFromJson(data['rating']);
  });

  @override
  Future<({RatingSummary rating, Review? review})> saveReview(
    String branchId,
    int stars,
    String text,
  ) => apiCall(() async {
    final data = (await _dio.put<Map<String, dynamic>>(
      '/places/branches/$branchId/review',
      data: {'stars': stars, 'text': text},
    )).data!;
    return (
      rating: ratingFromJson(data['rating']),
      review: data['review'] == null
          ? null
          : reviewFromJson(data['review'] as Map<String, dynamic>),
    );
  });

  @override
  Future<RatingSummary> removeReview(String branchId) => apiCall(() async {
    final data = (await _dio.delete<Map<String, dynamic>>(
      '/places/branches/$branchId/review',
    )).data!;
    return ratingFromJson(data['rating']);
  });

  @override
  Future<ReviewPage> reviews(String branchId, {int offset = 0}) =>
      apiCall(() async {
        final data = (await _dio.get<Map<String, dynamic>>(
          '/places/branches/$branchId/reviews',
          queryParameters: {'offset': offset},
        )).data!;
        return reviewPageFromJson(data);
      });

  @override
  Future<ReviewVotes> voteReview(String reviewId, ReviewVote? vote) =>
      apiCall(() async {
        final data = vote == null
            ? (await _dio.delete<Map<String, dynamic>>(
                '/places/reviews/$reviewId/vote',
              )).data!
            : (await _dio.put<Map<String, dynamic>>(
                '/places/reviews/$reviewId/vote',
                data: {'vote': vote.wire},
              )).data!;
        return reviewVotesFromJson(data['votes']);
      });

  @override
  Future<void> reportReview(
    String reviewId,
    ReviewReason reason,
    String? note,
  ) => apiCall(
    () => _dio.post<void>(
      '/places/reviews/$reviewId/report',
      data: {'reason': reason.wire, 'note': ?note},
    ),
  );

  @override
  Future<void> report(ReportDraft draft) => apiCall(
    () => _dio.post<void>(
      '/places/reports',
      data: {
        'target': {'type': draft.target.name, 'id': draft.targetId},
        'field': draft.field.name,
        'lat': ?draft.lat,
        'lng': ?draft.lng,
        'value': ?draft.value,
        'note': ?draft.note,
      },
    ),
  );

  @override
  Future<Place> saveBranch(String branchId) => apiCall(() async {
    final data = (await _dio.post<Map<String, dynamic>>(
      '/places',
      data: {'branchId': branchId},
    )).data!;
    return placeFromJson(data);
  });

  @override
  Future<List<PlaceHit>> search(
    String query,
    double lat,
    double lng, {
    bool submit = false,
  }) => apiCall(() async {
    final data = (await _dio.get<Map<String, dynamic>>(
      '/places/search',
      queryParameters: {
        'q': query.trim(),
        'lat': lat,
        'lng': lng,
        'submit': submit ? '1' : '0',
      },
    )).data!;
    return [
      for (final j in (data['items'] as List).cast<Map<String, dynamic>>())
        PlaceHit(
          branchId: j['branchId'] as String?,
          poiId: j['poiId'] as String?,
          name: j['name'] as String,
          address: j['address'] as String?,
          lat: (j['lat'] as num).toDouble(),
          lng: (j['lng'] as num).toDouble(),
          distanceM: (j['distanceM'] as num).toInt(),
          saved: j['saved'] as bool? ?? false,
        ),
    ];
  });

  // shortcut: FIFO, not LRU; a Home grid shows far fewer covers than this.
  final _covers = <String, Future<Uint8List?>>{};

  @override
  Future<Uint8List?> restaurantCover(String restaurantId, String cover) {
    if (_covers.length >= 80) _covers.remove(_covers.keys.first);
    final key = '$restaurantId/$cover';
    return _covers[key] ??= _bytes('/places/restaurants/$restaurantId/cover')
      ..catchError((Object _) {
        _covers.remove(key); // a failed fetch is tried again next time
        return null;
      });
  }

  @override
  Future<({List<String> covers, String? current})> coverCandidates(
    String restaurantId,
  ) => apiCall(() async {
    final j = (await _dio.get<Map<String, dynamic>>(
      '/places/restaurants/$restaurantId/covers',
    )).data!;
    return (
      covers: (j['covers'] as List).cast<String>(),
      current: j['current'] as String?,
    );
  });

  @override
  Future<Uint8List?> coverCandidate(String restaurantId, String cover) =>
      _bytes('/places/restaurants/$restaurantId/covers/$cover');

  @override
  Future<void> setRestaurantCover(String restaurantId, String? cover) =>
      apiCall(
        () => _dio.put<void>(
          '/places/restaurants/$restaurantId/cover',
          data: {'cover': cover},
        ),
      );

  /// Through Dio, not Image.network: the request needs the token (and its refresh); R2 is private. 404 = null.
  Future<Uint8List?> _bytes(String path) => apiCall(() async {
    final res = await _dio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (s) => s == 200 || s == 404,
      ),
    );
    return res.statusCode == 200 ? Uint8List.fromList(res.data!) : null;
  });

  @override
  Future<Place> savePoi(String poiId) => apiCall(() async {
    final data = (await _dio.post<Map<String, dynamic>>(
      '/places',
      data: {'poiId': poiId},
    )).data!;
    return placeFromJson(data);
  });
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

NearbyBranch nearbyBranchFromJson(Map<String, dynamic> j) => NearbyBranch(
  branchId: j['branchId'] as String,
  restaurantId: j['restaurantId'] as String,
  name: j['name'] as String,
  label: j['label'] as String?,
  address: j['address'] as String?,
  lat: (j['lat'] as num).toDouble(),
  lng: (j['lng'] as num).toDouble(),
  distanceM: (j['distanceM'] as num).toInt(),
  cuisine: j['cuisine'] as String?,
  halalClaim: j['halalClaim'] as String?,
  halalQuote: j['halalQuote'] as String?,
  halalSourceUrl: j['halalSourceUrl'] as String?,
  saved: j['saved'] as bool,
  placeId: j['placeId'] as String?,
  rating: ratingFromJson(j['rating']),
  cover: j['cover'] as String?,
);

ReviewVotes reviewVotesFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return const ReviewVotes();
  return ReviewVotes(
    up: (json['up'] as num?)?.toInt() ?? 0,
    down: (json['down'] as num?)?.toInt() ?? 0,
    mine: ReviewVote.fromWire(json['mine']),
  );
}

Review reviewFromJson(Map<String, dynamic> j) => Review(
  id: j['id'] as String,
  stars: (j['stars'] as num).toInt(),
  text: j['text'] as String,
  author: j['author'] as String,
  mine: j['mine'] as bool? ?? false,
  hidden: j['hidden'] as bool? ?? false,
  createdAt: dbTime(j['createdAt'] as String),
  updatedAt: dbTime(j['updatedAt'] as String),
  votes: reviewVotesFromJson(j['votes']),
  reported: j['reported'] as bool? ?? false,
  visited: j['visited'] as bool? ?? false,
);

ReviewPage reviewPageFromJson(Map<String, dynamic> j) {
  final branch = j['branch'] as Map<String, dynamic>;
  return ReviewPage(
    branchId: branch['id'] as String,
    branchName: branch['name'] as String,
    branchLabel: branch['label'] as String?,
    rating: ratingFromJson(branch['rating']),
    reviews: [
      for (final r in (j['reviews'] as List).cast<Map<String, dynamic>>())
        reviewFromJson(r),
    ],
    nextOffset: (j['nextOffset'] as num?)?.toInt(),
  );
}

Place placeFromJson(Map<String, dynamic> j) {
  final r = j['restaurant'] as Map<String, dynamic>;
  return Place(
    id: j['id'] as String,
    mine: j['mine'] as bool? ?? true,
    private: j['private'] as bool? ?? false,
    savedBy: [
      for (final s
          in (j['savedBy'] as List? ?? const []).cast<Map<String, dynamic>>())
        (name: s['name'] as String?, isMe: s['isMe'] as bool),
    ],
    note: j['note'] as String?,
    createdAt: dbTime(j['createdAt'] as String),
    branchId: j['branchId'] as String?,
    sourceUrl: j['sourceUrl'] as String?,
    shareId: j['shareId'] as String?,
    restaurant: PlaceRestaurant(
      id: r['id'] as String,
      name: r['name'] as String,
      cuisine: r['cuisine'] as String?,
      halalClaim: r['halalClaim'] as String?,
      halalQuote: r['halalQuote'] as String?,
      halalSourceUrl: r['halalSourceUrl'] as String?,
      cover: r['cover'] as String?,
    ),
    branches: [
      for (final b in (j['branches'] as List).cast<Map<String, dynamic>>())
        Branch(
          id: b['id'] as String,
          label: b['label'] as String?,
          address: b['address'] as String?,
          city: b['city'] as String?,
          state: b['state'] as String?,
          lat: _num(b['lat']),
          lng: _num(b['lng']),
          pinSource: b['pinSource'] as String?,
          rating: ratingFromJson(b['rating']),
        ),
    ],
  );
}
