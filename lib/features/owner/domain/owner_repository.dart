import 'owner.dart';

/// Owner-only API (/owner/*). Every method throws ApiException (core/network) on failure.
abstract interface class OwnerRepository {
  Future<OwnerStats> getStats();

  /// Only the given fields change. [period] is 'day' or 'month'.
  Future<Meter> updateMeter(
    String code, {
    int? cap,
    String? period,
    bool? active,
  });

  /// Newest first; [query] matches part of the email.
  Future<List<OwnerUser>> listUsers({String? query});

  /// Signs the user out on every device.
  Future<void> endSessions(String userId);

  /// Newest first.
  Future<List<FailedShare>> failedShares();

  /// Community report tickets. [status] is 'open' or 'closed'.
  Future<List<ReportTicket>> reports({String status = 'open'});

  /// Applies or rejects the open ticket for one target + field. The ticket always closes.
  Future<void> resolveReport({
    required String targetType,
    required String targetId,
    required String field,
    required bool apply,
  });

  Future<List<ReviewReportGroup>> reviewReports();

  Future<void> resolveReviewReport({
    required String reviewId,
    required bool hide,
  });

  Future<List<RatingBurst>> ratingBursts();

  /// Deletes a rating and its review for good (its votes and reports too).
  Future<void> deleteRating(String ratingId);
}
