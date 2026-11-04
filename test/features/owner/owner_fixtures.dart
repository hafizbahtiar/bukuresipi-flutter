import 'package:bukuresipi_flutter/features/owner/domain/owner.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';

Meter meter({
  String code = 'geo:nominatim',
  int used = 90,
  int cap = 100,
  bool active = true,
}) =>
    Meter(code: code, name: 'Nominatim', used: used, cap: cap, active: active);

OwnerUser ownerUser(String email, {bool verified = true, int shares = 0}) =>
    OwnerUser(
      id: 'u-$email',
      email: email,
      role: 'user',
      verified: verified,
      createdAt: DateTime.utc(2026, 11, 1),
      shares: shares,
    );

class FakeOwner implements OwnerRepository {
  OwnerStats stats = OwnerStats(
    usersTotal: 12,
    usersNewThisWeek: 3,
    sharesToday: 7,
    failedToday: 2,
    meters: [meter()],
  );
  List<OwnerUser> users = [];
  List<FailedShare> shares = [];
  List<ReportTicket> tickets = [];
  final queries = <String?>[];
  final reportQueries = <String>[];
  final loggedOut = <String>[];
  final meterUpdates = <(String, int?, String?, bool?)>[];
  final resolved = <(String, String, bool)>[];
  final reviewResolved = <(String, bool)>[];
  List<ReviewReportGroup> reviewReportGroups = [];

  @override
  Future<OwnerStats> getStats() async => stats;

  @override
  Future<Meter> updateMeter(
    String code, {
    int? cap,
    String? period,
    bool? active,
  }) async {
    meterUpdates.add((code, cap, period, active));
    final m = stats.meters.firstWhere((m) => m.code == code);
    return Meter(
      code: code,
      name: m.name,
      used: m.used,
      cap: cap ?? m.cap,
      active: active ?? m.active,
      period: period ?? m.period,
    );
  }

  @override
  Future<List<OwnerUser>> listUsers({String? query}) async {
    queries.add(query);
    return [
      for (final u in users)
        if (query == null || u.email.contains(query)) u,
    ];
  }

  @override
  Future<void> endSessions(String userId) async => loggedOut.add(userId);

  @override
  Future<List<FailedShare>> failedShares() async => shares;

  @override
  Future<List<ReportTicket>> reports({String status = 'open'}) async {
    reportQueries.add(status);
    return tickets.where((t) => t.status == status).toList();
  }

  @override
  Future<void> resolveReport({
    required String targetType,
    required String targetId,
    required String field,
    required bool apply,
  }) async {
    resolved.add((targetId, field, apply));
  }

  @override
  Future<List<ReviewReportGroup>> reviewReports() async => reviewReportGroups;

  @override
  Future<void> resolveReviewReport({
    required String reviewId,
    required bool hide,
  }) async {
    reviewResolved.add((reviewId, hide));
  }
}
