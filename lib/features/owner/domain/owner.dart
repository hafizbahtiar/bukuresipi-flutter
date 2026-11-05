class OwnerStats {
  const OwnerStats({
    required this.usersTotal,
    required this.usersNewThisWeek,
    required this.sharesToday,
    required this.failedToday,
    required this.meters,
    this.reportsOpen = 0,
    this.reportsReady = 0,
    this.reviewReportsOpen = 0,
    this.ratingBursts = 0,
    this.testers = 0,
  });

  final int usersTotal;
  final int usersNewThisWeek;
  final int sharesToday;

  /// Failed, or done with a gap (unreadable, branches pending...).
  final int failedToday;
  final List<Meter> meters;

  /// Community report tickets: open, and open ones that reached the threshold.
  final int reportsOpen;
  final int reportsReady;
  final int reviewReportsOpen;

  /// Branches rated by several new accounts this week.
  final int ratingBursts;

  /// Website signups for the Android closed test.
  final int testers;

  OwnerStats withMeter(Meter m) => OwnerStats(
    usersTotal: usersTotal,
    usersNewThisWeek: usersNewThisWeek,
    sharesToday: sharesToday,
    failedToday: failedToday,
    meters: [for (final x in meters) x.code == m.code ? m : x],
    reportsOpen: reportsOpen,
    reportsReady: reportsReady,
    reviewReportsOpen: reviewReportsOpen,
    ratingBursts: ratingBursts,
    testers: testers,
  );
}

/// A website signup for the Android closed test (a Google account email, pasted into the Play Console).
class Tester {
  const Tester({
    required this.email,
    required this.lang,
    required this.joinedAt,
  });

  final String email;
  final String lang;
  final DateTime joinedAt;
}

/// A branch rated by several brand-new accounts in one week: maybe fake accounts. [ratings]: every rating on it this
/// week, newest first.
class RatingBurst {
  const RatingBurst({
    required this.branchId,
    required this.restaurant,
    this.label,
    required this.newAccounts,
    required this.ratings,
  });

  final String branchId;
  final String restaurant;
  final String? label;
  final int newAccounts;
  final List<BurstRating> ratings;
}

class BurstRating {
  const BurstRating({
    required this.id,
    required this.stars,
    this.text,
    required this.hidden,
    required this.createdAt,
    required this.email,
    required this.joinedAt,
    required this.emailVerified,
  });

  final String id;
  final int stars;
  final String? text;
  final bool hidden;
  final DateTime createdAt;
  final String email;
  final DateTime joinedAt;
  final bool emailVerified;
}

class ReviewReportGroup {
  const ReviewReportGroup({
    required this.reviewId,
    required this.stars,
    required this.text,
    required this.author,
    required this.hidden,
    required this.createdAt,
    required this.count,
    required this.reasons,
    required this.updatedAt,
    this.latestNote,
  });

  final String reviewId;
  final int stars;
  final String text;
  final String author;
  final bool hidden;
  final DateTime createdAt;
  final int count;
  final List<String> reasons;
  final String? latestNote;
  final DateTime updatedAt;
}

class ReportValue {
  const ReportValue({this.lat, this.lng, this.value});

  final double? lat;
  final double? lng;
  final String? value;

  String get label {
    if (lat != null && lng != null) {
      return '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}';
    }
    return value ?? '—';
  }
}

/// One owner report ticket: open, or closed as applied/rejected.
class ReportTicket {
  const ReportTicket({
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.field,
    required this.count,
    required this.threshold,
    required this.status,
    required this.ready,
    required this.updatedAt,
    this.targetLabel,
    this.current = const ReportValue(),
    this.proposed,
    this.latestNote,
    this.verifiedAt,
  });

  final String targetType;
  final String targetId;
  final String targetName;
  final String? targetLabel;
  final String field;
  final int count;
  final int threshold;
  final ReportValue current;
  final ReportValue? proposed;
  final String status;
  final bool ready;
  final String? latestNote;
  final DateTime? verifiedAt;
  final DateTime updatedAt;

  String get title => targetLabel == null || targetLabel == targetName
      ? targetName
      : '$targetName · $targetLabel';
}

/// One outside service (system_subscription): calls this month vs. the cap. Off or at the cap = calls refused.
class Meter {
  const Meter({
    required this.code,
    required this.name,
    required this.used,
    required this.cap,
    required this.active,
    this.vendorUrl,
    this.period = 'month',
  });

  final String code;
  final String name;
  final int used;
  final int cap;
  final bool active;
  final String? vendorUrl;

  /// 'day' or 'month': what [cap] and [used] count.
  final String period;

  /// 0..1 of the cap used (1 when the cap is 0).
  double get share => cap <= 0 ? 1 : (used / cap).clamp(0, 1).toDouble();
}

class OwnerUser {
  const OwnerUser({
    required this.id,
    required this.email,
    required this.role,
    required this.verified,
    required this.createdAt,
    required this.shares,
  });

  final String id;
  final String email;
  final String role;
  final bool verified;
  final DateTime createdAt;
  final int shares;
}

/// A share the pipeline could not finish or read. No user: the owner tunes the pipeline, not people.
class FailedShare {
  const FailedShare({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.kind,
    required this.input,
    required this.gaps,
    this.platform,
    this.sourceUrl,
    this.error,
    this.caption,
  });

  final String id;
  final DateTime createdAt;
  final String status;
  final String kind;
  final String input;
  final List<String> gaps;
  final String? platform;
  final String? sourceUrl;
  final String? error;
  final String? caption;
}
