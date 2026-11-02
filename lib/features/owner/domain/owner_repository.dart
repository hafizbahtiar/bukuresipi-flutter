import 'owner.dart';

/// Owner-only API (/owner/*). Every method throws ApiException (core/network) on failure.
abstract interface class OwnerRepository {
  Future<OwnerStats> getStats();

  /// Only the given fields change.
  Future<Meter> updateMeter(String code, {int? monthlyCap, bool? active});

  /// Newest first; [query] matches part of the email.
  Future<List<OwnerUser>> listUsers({String? query});

  /// Signs the user out on every device.
  Future<void> endSessions(String userId);

  /// Newest first.
  Future<List<FailedShare>> failedShares();
}
