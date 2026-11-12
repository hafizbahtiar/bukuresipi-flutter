import 'dart:typed_data';

import 'nearby_branch.dart';
import 'place.dart';
import 'rating.dart';
import 'report.dart';
import 'review.dart';

/// The user's saved places. Every method throws ApiException (core/network) on failure.
abstract interface class PlacesRepository {
  /// Newest first.
  Future<List<Place>> list();

  /// Empty or blank [note] clears it.
  Future<void> updateNote(String id, String? note);

  /// "Only me": keeps the caller's own save out of the family book.
  Future<void> setPrivate(String id, bool private);

  /// The user's own pin for an unpinned branch (one per user + branch; moving it replaces it).
  Future<void> setPin(String branchId, double lat, double lng);

  /// Looks an unpinned branch up again on the server.
  Future<LocateResult> locate(String branchId);

  /// Owner only: merges branches that are the same shop and drops empty ones, for every user.
  Future<({int merged, int removed})> tidyBranches(String placeId);

  /// Owner: restaurants that are one company become [into] (renamed to [name] when given).
  Future<void> mergePlaces(List<String> from, String into, {String? name});

  /// Owner only: removes the branch for every user.
  Future<void> deleteBranch(String branchId);

  /// Owner only: the main place's name, category and cuisine, shared by every user (null cuisine = cleared).
  Future<void> updatePlace(
    String placeId, {
    required String name,
    required String category,
    String? subcategory,
    String? cuisine,
  });

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

  /// Owner only: another branch of [branchId]'s restaurant. Throws 'branch_label_taken'.
  Future<void> addSiblingBranch(
    String branchId, {
    String? address,
    String? city,
    String? state,
    required double lat,
    required double lng,
  });

  /// Owner only: an AI/map draft for a branch. It never saves; the owner applies it.
  Future<BranchSuggestion> suggestBranch(String branchId);

  /// The 16 states with their towns, A-Z (the branch form's dropdowns).
  Future<List<AreaState>> areas();

  /// A pasted Google Maps link -> its pin (nothing saved). Throws ApiException 'not_maps_link' / 'no_pin'.
  Future<MapsPin> pinFromMapsLink(String url);

  /// Owner: [source] 'osm' | 'here' | 'grab'; [q] null = the shop name + area. Throws `source_off` (no key, meter off).
  Future<({String query, List<PinHit> hits})> searchPin(
    String branchId,
    String source, {
    String? q,
  });

  /// The restaurant's chosen cover photo; null = none. [cover] is the id from the DTO (cache key).
  Future<Uint8List?> placeCover(String placeId, String cover);

  /// Owner only: the post thumbnails to pick a cover from, and the current pick.
  Future<({List<String> covers, String? current})> coverCandidates(
    String placeId,
  );

  /// Owner only: one candidate's image.
  Future<Uint8List?> coverCandidate(String placeId, String cover);

  /// Owner only: picks a candidate as the cover for everyone; null clears it.
  Future<void> setRestaurantCover(String placeId, String? cover);

  /// Owner only: a photo from the AI draft's web pages as the cover (the server downloads it). Throws ApiException.
  Future<void> setRestaurantCoverUrl(String placeId, String url);

  /// Owner only: a photo of their own ([path] = the editor's JPEG) as the cover. Throws ApiException.
  Future<void> uploadRestaurantCover(String placeId, String path);

  /// Community rating; the response is the branch's fresh summary.
  Future<RatingSummary> rateBranch(String branchId, int stars);

  /// Removes the caller's rating; the response is the fresh summary.
  Future<RatingSummary> clearRating(String branchId);

  /// Writes/edits the optional review text with the caller's stars.
  Future<({RatingSummary rating, Review? review})> saveReview(
    String branchId,
    int stars,
    String text,
  );

  /// Removes only the review text; the rating stays.
  Future<RatingSummary> removeReview(String branchId);

  Future<ReviewPage> reviews(String branchId, {int offset = 0});

  Future<ReviewVotes> voteReview(String reviewId, ReviewVote? vote);

  Future<void> reportReview(String reviewId, ReviewReason reason, String? note);

  /// Takes the place off this user's map (the restaurant stays for others).
  Future<void> remove(String id);

  /// Pinned branches within [km] of a point (the phone's fix), nearest first.
  Future<List<NearbyBranch>> nearby(double lat, double lng, double km);

  /// Saves an existing branch's restaurant to this user's map.
  Future<Place> saveBranch(String branchId);

  /// Places named like [query], nearest to (lat, lng) first. [submit] = the user pressed Search: logged, and the
  /// server may ask OpenStreetMap; while typing, our data only.
  Future<List<PlaceHit>> search(
    String query,
    double lat,
    double lng, {
    bool submit = false,
  });

  /// Saves a search result that is not in the app yet (it becomes a restaurant).
  Future<Place> savePoi(String poiId);

  /// Community suggestion; saved as an open ticket for the owner to verify.
  Future<void> report(ReportDraft draft);
}
