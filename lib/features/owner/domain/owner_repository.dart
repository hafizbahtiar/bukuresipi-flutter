import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_variant.dart';
import 'owner.dart';

/// What POST /owner/recipes/:id/draft answers. complete = false: a usage cap or a missing key; the draft is the dish
/// as it is.
typedef DishDraft = ({
  String name,
  List<String> ingredients,
  List<String> steps,
  List<({String url, String? title})> sources,
  List<String> images,
  List<String> warnings,
  bool complete,
});

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
  /// Throws 'owner_account'. Returns whether the user was emailed (false = the send failed; the ban still holds).
  Future<bool> ban(String userId, {int? days, required String reason});

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

  /// What the owner hid, last hidden first (the newest 100 of each).
  Future<({List<HiddenRecipe> recipes, List<HiddenReview> reviews})>
  hiddenContent();

  Future<void> unhideRecipe(String recipeId);

  Future<void> unhideReview(String reviewId);

  /// Searches the web for a catalogue dish's variants (metered) and replaces the stored list.
  /// complete = false: a usage cap stopped part of it.
  Future<({List<RecipeVariant> variants, bool complete})> findVariants(
    String recipeId,
  );

  /// An AI draft of a catalogue dish or the owner's own recipe from web recipes (metered: 1 search + 1 AI call). Nothing is saved: the edit
  /// form shows it and the owner saves it.
  Future<DishDraft> draftDish(String recipeId);

  /// A draft photo (its URL) as the cover of a catalogue dish or the owner's own recipe: the server downloads and keeps it. The dish as saved.
  Future<RecipeDetail> setDishCover(String recipeId, String url);

  /// Every pinned branch, for the owner's map.
  Future<List<OwnerPlace>> places();

  /// Done: [email] is in the Play closed test; the server emails them the opt-in link (again = sent again).
  Future<void> inviteTester(String email);

  /// Website tester signups, oldest first.
  Future<List<Tester>> testers();

  /// Unlinked lines grouped, most first (100), and the catalogue's categories for a new ingredient.
  Future<({List<IngredientGap> gaps, List<String> categories})>
  ingredientGaps();

  /// Catalogue ingredient names for what the owner types (2+ characters).
  Future<List<String>> searchIngredients(String query);

  /// How many unlinked lines [alias] would link to [ingredient] (a catalogue name), and some of them; nothing is
  /// saved. Throws 'name_taken' (already a name or an alias) or 'not_found'.
  Future<({int lines, List<String> sample})> previewAlias(
    String ingredient,
    String alias,
  );

  /// Saves the alias and relinks every unlinked line: how many it linked. Throws as [previewAlias].
  Future<int> addAlias(String ingredient, String alias);

  /// A new catalogue ingredient; every unlinked line is matched again: how many it linked. Throws 'name_taken'.
  Future<int> addIngredient(String name, String category);

  /// Matches every unlinked line again (after a migration added names by hand).
  Future<({int checked, int linked})> relinkIngredients();

  /// What was added in the app, as markdown rows for docs/plans/ingredient.md and ingredient_alias.md.
  Future<({String ingredients, String aliases})> addedIngredientRows();
}
