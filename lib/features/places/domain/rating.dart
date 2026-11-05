/// The server-computed rating for one branch. `average` is null until there are at least 3 ratings.
class RatingSummary {
  const RatingSummary({
    this.average,
    this.count = 0,
    this.mine,
    this.canRate = false,
    this.reviewCount = 0,
    this.myReview = false,
  });

  final double? average;
  final int count;
  final int? mine;
  final bool canRate;
  final int reviewCount;
  final bool myReview;

  bool get hasAverage => average != null;

  RatingSummary copyWith({
    double? average,
    int? count,
    int? mine,
    bool? canRate,
    int? reviewCount,
    bool? myReview,
  }) => RatingSummary(
    average: average ?? this.average,
    count: count ?? this.count,
    mine: mine ?? this.mine,
    canRate: canRate ?? this.canRate,
    reviewCount: reviewCount ?? this.reviewCount,
    myReview: myReview ?? this.myReview,
  );
}

RatingSummary ratingFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return const RatingSummary();
  return RatingSummary(
    average: (json['average'] as num?)?.toDouble(),
    count: (json['count'] as num?)?.toInt() ?? 0,
    mine: (json['mine'] as num?)?.toInt(),
    canRate: json['canRate'] as bool? ?? false,
    reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    myReview: json['myReview'] as bool? ?? false,
  );
}
