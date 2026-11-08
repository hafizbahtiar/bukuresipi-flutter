import '../../recipes/domain/recipe_variant.dart';
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

  /// Bans for [days] (null = for good) with the [reason] the user is shown; ends their sessions.
  /// Throws 'owner_account'.
  Future<void> ban(String userId, {int? days, required String reason});

  Future<void> unban(String userId);

  /// Deletes the account and all its data. [banEmail] = its email and Google account can't sign up again.
  Future<void> deleteUser(
    String userId, {
    required String reason,
    bool banEmail = false,
  });

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

  /// Takes a public recipe off Community (its open reports close as hidden). The author still sees it.
  Future<void> hideRecipe(String recipeId);

  /// Searches the web for a catalogue dish's variants (metered) and replaces the stored list.
  /// complete = false: a usage cap stopped part of it.
  Future<({List<RecipeVariant> variants, bool complete})> findVariants(
    String recipeId,
  );

  /// Every pinned branch, for the owner's map.
  Future<List<OwnerPlace>> places();

  /// Done: [email] is in the Play closed test; the server emails them the opt-in link (again = sent again).
  Future<void> inviteTester(String email);

  /// Website tester signups, oldest first.
  Future<List<Tester>> testers();
}
