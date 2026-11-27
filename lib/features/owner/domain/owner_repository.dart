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

  /// Every catalogue ingredient, A-Z.
  Future<List<IngredientRow>> listIngredients();

  /// One ingredient's page. Throws 'not_found'.
  Future<IngredientDetail> ingredientDetail(int id);

  /// A new name and/or category; the old name stays as another name. Throws 'name_taken'.
  Future<IngredientDetail> updateIngredient(
    int id, {
    String? name,
    String? category,
  });

  /// How many lines only [alias] matched (they go back to the gaps), and some of them. Nothing saved.
  Future<({int lines, List<String> sample})> previewRemoveAlias(
    int id,
    String alias,
  );

  /// Removes [alias] from ingredient [id]: how many lines it unlinked (or moved to another match).
  Future<int> removeAlias(int id, String alias);

  /// How many lines say [alias] and would move if it became its own ingredient. Nothing saved.
  Future<({int lines, List<String> sample})> previewSplitAlias(
    int id,
    String alias,
  );

  /// [alias] of ingredient [id] becomes its own ingredient (same category); the lines that say it move there.
  Future<({int id, String name, int moved})> splitAlias(int id, String alias);

  /// Saves the alias and relinks every unlinked line: how many it linked. Throws as [previewAlias].
  Future<int> addAlias(String ingredient, String alias);

  /// Several aliases, then one relink of every unlinked line (one pass, not one per alias); taken names and
  /// unknown ingredients are skipped. Returns how many were saved and how many lines they linked.
  Future<({int saved, int linked})> addAliases(
    List<({String ingredient, String alias})> items,
  );

  /// Owner > AI: the providers and models offered, the default and every use.
  Future<AiSettings> aiSettings();

  /// [use] = 'default' or a use id. Throws 'ai_unknown_model' / 'ai_no_images'.
  Future<AiSettings> saveAiSetting(String use, AiSetting setting);

  /// The use follows the default again.
  Future<AiSettings> clearAiSetting(String use);

  /// Open suggestions from recipe lines, most recipes first.
  Future<List<CatalogueSuggestion>> catalogueSuggestions();

  /// [name] is now in the catalogue as [target]: each suggesting line still worded so and without a pick gets it.
  /// Returns how many lines were linked; all of the name's suggestions are closed.
  Future<int> resolveSuggestion(String name, PickRef target);

  Future<void> dismissSuggestion(String name);

  /// A new catalogue ingredient; every unlinked line is matched again: how many it linked. Throws 'name_taken'.
  Future<int> addIngredient(String name, String category);

  /// A message to one user ([to] = their id) or everyone ([to] null): in the inbox and pushed to their phones.
  /// [kind] 'update' = a tap opens the Play update, not the inbox. [image] = a local JPEG path, shown in the push and
  /// the inbox.
  Future<void> sendMessage({
    required String title,
    required String body,
    String? to,
    String kind = 'message',
    String? image,
  });

  /// What the owner sent, newest first.
  Future<List<SentMessage>> sentMessages();

  /// Takes a sent message back: out of every inbox; a push still going stops. Throws 'not_found'.
  Future<void> deleteMessage(int id);

  /// AI: what [line] names (Malay, lowercase) and the catalogue ingredient that is, if any. Nothing saved.
  /// Throws 'ai_unavailable'.
  Future<GapSuggestion> suggestGap(String line);

  /// AI: aliases for 20 ingredients (fewest aliases first) from [offset], each with the lines it would link;
  /// next = null at the end. Nothing saved (save with [addAliases]). Throws 'ai_unavailable'.
  Future<({List<AliasSuggestion> items, int? next})> suggestAliases(int offset);

  /// Matches every unlinked line again (after a migration added names by hand).
  Future<({int checked, int linked})> relinkIngredients();

  /// What was added in the app, as markdown rows for docs/plans/ingredient.md and ingredient_alias.md.
  Future<({String ingredients, String aliases})> addedIngredientRows();

  /// Owner > Catalogue lists, 50 a page, by name ([query] also matches a brand's maker, a product's brand and
  /// ingredient).
  Future<CataloguePage<CatalogueMaker>> makers({String? query, int offset = 0});
  Future<(CataloguePage<CatalogueBrand>, List<String> countries)> brands({
    String? query,
    int offset = 0,
  });
  Future<(CataloguePage<CatalogueProduct>, List<String> units)> products({
    String? query,
    int offset = 0,
  });

  /// New when [id] is null. Throws 'name_taken' (makers and brands, ignoring case) or 'not_found' (a link that is
  /// gone, or a product's ingredient name the catalogue does not have).
  Future<void> saveMaker({int? id, required String name});
  Future<void> saveBrand({
    int? id,
    required String name,
    int? makerId,
    String? country,
  });

  /// Fills a product form from a [barcode] (Open Food Facts), a store [url] or a product [name] (web search); one
  /// of the three. Nothing saved. Throws 'not_found' (an unknown barcode, no store page for the name),
  /// 'unreadable' (no product on that page), 'ai_unavailable' (no search left).
  Future<ProductFill> fillProduct({String? barcode, String? url, String? name});

  Future<void> saveProduct({
    int? id,
    required String name,
    String? ingredient,
    int? brandId,
    double? size,
    String? unit,
  });

  /// [kind] is 'makers', 'brands' or 'products'. What used it stays, without it.
  Future<void> deleteCatalogueRow(String kind, int id);

  /// Added and changed rows, as markdown for docs/plans/manufacturer.md, brand.md and product.md.
  Future<({String makers, String brands, String products})> catalogueRows();
}
