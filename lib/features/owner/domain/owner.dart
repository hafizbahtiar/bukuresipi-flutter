class OwnerStats {
  const OwnerStats({
    required this.usersTotal,
    required this.usersNewThisWeek,
    required this.sharesToday,
    required this.failedToday,
    required this.meters,
  });

  final int usersTotal;
  final int usersNewThisWeek;
  final int sharesToday;

  /// Failed, or done with a gap (unreadable, branches pending...).
  final int failedToday;
  final List<Meter> meters;

  OwnerStats withMeter(Meter m) => OwnerStats(
    usersTotal: usersTotal,
    usersNewThisWeek: usersNewThisWeek,
    sharesToday: sharesToday,
    failedToday: failedToday,
    meters: [for (final x in meters) x.code == m.code ? m : x],
  );
}

/// One outside service (system_subscription): calls this month vs. the cap. Off or at the cap = calls refused.
class Meter {
  const Meter({
    required this.code,
    required this.name,
    required this.used,
    required this.monthlyCap,
    required this.active,
    this.vendorUrl,
  });

  final String code;
  final String name;
  final int used;
  final int monthlyCap;
  final bool active;
  final String? vendorUrl;

  /// 0..1 of the cap used (1 when the cap is 0).
  double get share =>
      monthlyCap <= 0 ? 1 : (used / monthlyCap).clamp(0, 1).toDouble();
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
