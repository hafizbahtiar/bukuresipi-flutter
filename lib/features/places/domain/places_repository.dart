import 'nearby_branch.dart';
import 'place.dart';
import 'report.dart';

/// The user's saved places. Every method throws ApiException (core/network) on failure.
abstract interface class PlacesRepository {
  /// Newest first.
  Future<List<Place>> list();

  /// Empty or blank [note] clears it.
  Future<void> updateNote(String id, String? note);

  /// The user's own pin for an unpinned branch (one per user + branch; moving it replaces it).
  Future<void> setPin(String branchId, double lat, double lng);

  /// Looks an unpinned branch up again on the server. true = it has a pin now.
  Future<bool> locate(String branchId);

  /// Owner only: merges branches that are the same shop and drops empty ones, for every user.
  Future<({int merged, int removed})> tidyBranches(String restaurantId);

  /// Owner only: removes the branch for every user.
  Future<void> deleteBranch(String branchId);

  /// Edits a branch. [scope] personal keeps it private; shared is owner-only and claims new coordinates
  /// as 'owner'. Passing [lat]/[lng] moves the pin in that scope.
  Future<void> updateBranch(
    String branchId, {
    String? label,
    String? address,
    String? city,
    String? state,
    double? lat,
    double? lng,
    BranchEditScope scope = BranchEditScope.personal,
  });

  /// Takes the place off this user's map (the restaurant stays for others).
  Future<void> remove(String id);

  /// Pinned branches within [km] of a point (the phone's fix), nearest first.
  Future<List<NearbyBranch>> nearby(double lat, double lng, double km);

  /// Saves an existing branch's restaurant to this user's map.
  Future<Place> saveBranch(String branchId);

  /// Community suggestion; saved as an open ticket for the owner to verify.
  Future<void> report(ReportDraft draft);
}
