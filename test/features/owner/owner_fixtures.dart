import 'package:bukuresipi_flutter/core/network/api_exception.dart';

import 'dart:async';

import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe_variant.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';

Meter meter({
  String code = 'geo:nominatim',
  int used = 90,
  int cap = 100,
  bool active = true,
}) =>
    Meter(code: code, name: 'Nominatim', used: used, cap: cap, active: active);

OwnerUser ownerUser(
  String email, {
  bool verified = true,
  int shares = 0,
  String role = 'user',
  ({DateTime? until, String? reason})? ban,
}) => OwnerUser(
  id: 'u-$email',
  email: email,
  role: role,
  verified: verified,
  createdAt: DateTime.utc(2026, 11, 1),
  shares: shares,
  ban: ban,
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
  List<RatingBurst> bursts = [];
  List<Tester> testerList = [];
  final deletedRatings = <String>[];

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

  /// (user, days, reason); days null = for good.
  final bans = <(String, int?, String)>[];
  final unbans = <String>[];

  /// (user, reason, banEmail).
  final deleted = <(String, String, bool)>[];

  bool banEmailed = true;

  @override
  Future<bool> ban(String userId, {int? days, required String reason}) async {
    bans.add((userId, days, reason));
    return banEmailed;
  }

  @override
  Future<void> unban(String userId) async => unbans.add(userId);

  /// Set to hold each delete until it completes (to see what shows meanwhile).
  Completer<void>? deleteGate;

  @override
  Future<void> deleteUser(
    String userId, {
    required String reason,
    bool banEmail = false,
  }) async {
    await deleteGate?.future;
    deleted.add((userId, reason, banEmail));
  }

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

  @override
  Future<List<RatingBurst>> ratingBursts() async => bursts;

  @override
  Future<List<Tester>> testers() async => testerList;

  final invited = <String>[];

  @override
  Future<void> inviteTester(String email) async => invited.add(email);

  @override
  Future<List<OwnerPlace>> places() async => const [];

  List<RecipeVariant> foundVariants = const [];
  final variantSearches = <String>[];

  @override
  Future<({List<RecipeVariant> variants, bool complete})> findVariants(
    String recipeId,
  ) async {
    variantSearches.add(recipeId);
    return (variants: foundVariants, complete: true);
  }

  DishDraft? draft;
  final drafted = <String>[];

  /// Holds the draft back until completed (to see the page while it works).
  Completer<void>? draftGate;

  @override
  Future<DishDraft> draftDish(String recipeId) async {
    drafted.add(recipeId);
    await draftGate?.future;
    return draft!;
  }

  final dishCovers = <(String, String)>[];
  RecipeDetail? dishCoverResult;

  @override
  Future<RecipeDetail> setDishCover(String recipeId, String url) async {
    dishCovers.add((recipeId, url));
    return dishCoverResult!;
  }

  final hiddenRecipes = <String>[];

  @override
  Future<void> hideRecipe(String recipeId) async => hiddenRecipes.add(recipeId);

  var hiddenList = <HiddenRecipe>[];
  var hiddenReviews = <HiddenReview>[];
  final unhidden = <String>[];
  Object? unhideError;

  @override
  Future<({List<HiddenRecipe> recipes, List<HiddenReview> reviews})>
  hiddenContent() async => (recipes: hiddenList, reviews: hiddenReviews);

  @override
  Future<void> unhideRecipe(String recipeId) async {
    if (unhideError case final e?) throw e;
    unhidden.add(recipeId);
  }

  @override
  Future<void> unhideReview(String reviewId) async {
    if (unhideError case final e?) throw e;
    unhidden.add(reviewId);
  }

  @override
  Future<void> deleteRating(String ratingId) async {
    deletedRatings.add(ratingId);
    for (final b in bursts) {
      b.ratings.removeWhere((r) => r.id == ratingId);
    }
  }

  List<IngredientGap> gaps = const [];
  List<String> catalogue = const ['Minyak masak', 'Minyak zaitun', 'Garam'];
  final aliases = <(String, String)>[];
  final newIngredients = <(String, String)>[];
  int relinks = 0;

  @override
  Future<({List<IngredientGap> gaps, List<String> categories})>
  ingredientGaps() async => (gaps: gaps, categories: const ['Lain', 'Rempah']);

  @override
  Future<List<String>> searchIngredients(String query) async => [
    for (final c in catalogue)
      if (c.toLowerCase().contains(query.toLowerCase())) c,
  ];

  @override
  Future<({int lines, List<String> sample})> previewAlias(
    String ingredient,
    String alias,
  ) async {
    if (alias == 'garam') throw const ApiException('name_taken', status: 409);
    return (lines: 3, sample: const ['sedikit minyak', '2 sudu minyak']);
  }

  ({String? name, String? ingredient}) gapAnswer = (
    name: 'minyak masak',
    ingredient: 'Minyak masak',
  );
  List<AliasSuggestion> aliasAnswer = const [
    (ingredient: 'Bawang putih', alias: 'garlic', lines: 12),
    (ingredient: 'Bawang putih', alias: 'garlics', lines: 0),
  ];

  final fills = <String>[];
  ProductFill fillAnswer = (
    name: 'Kara UHT Coconut Cream 200ml',
    brand: 'Kara',
    brandIsNew: true,
    size: 200,
    unit: 'ml',
    ingredient: 'Santan',
    aiIngredient: true,
    source: 'https://www.jayagrocer.com/products/kara-uht-coconut-cream-200ml',
    maker: (
      name: 'PT Kara Santan Pertama',
      country: 'Indonesia',
      source: 'https://kara.test/about',
    ),
    similar: const [],
  );

  @override
  Future<ProductFill> fillProduct({
    String? barcode,
    String? url,
    String? name,
  }) async {
    fills.add(barcode ?? url ?? name!);
    if (barcode == '0000000000000') {
      throw const ApiException('not_found', status: 404);
    }
    return fillAnswer;
  }

  @override
  Future<({String? name, String? ingredient})> suggestGap(String line) async =>
      gapAnswer;

  @override
  Future<({List<AliasSuggestion> items, int? next})> suggestAliases(
    int offset,
  ) async => (
    items: offset == 0 ? aliasAnswer : const <AliasSuggestion>[],
    next: null,
  );

  @override
  Future<int> addAlias(String ingredient, String alias) async {
    aliases.add((ingredient, alias));
    gaps = const [];
    return 3;
  }

  @override
  Future<List<CatalogueSuggestion>> catalogueSuggestions() async =>
      suggestionList;

  List<CatalogueSuggestion> suggestionList = const [];
  final resolvedSuggestions = <(String, PickRef)>[];
  final dismissed = <String>[];

  @override
  Future<int> resolveSuggestion(String name, PickRef target) async {
    resolvedSuggestions.add((name, target));
    final linked =
        suggestionList.where((s) => s.name == name).firstOrNull?.recipes ?? 0;
    suggestionList = [...suggestionList.where((s) => s.name != name)];
    return linked;
  }

  @override
  Future<void> dismissSuggestion(String name) async {
    dismissed.add(name);
    suggestionList = [...suggestionList.where((s) => s.name != name)];
  }

  @override
  Future<({int saved, int linked})> addAliases(
    List<({String ingredient, String alias})> items,
  ) async {
    aliasBatches++;
    for (final i in items) {
      aliases.add((i.ingredient, i.alias));
    }
    gaps = const [];
    return (saved: items.length, linked: 3);
  }

  int aliasBatches = 0;

  @override
  Future<int> addIngredient(String name, String category) async {
    newIngredients.add((name, category));
    gaps = const [];
    return 1;
  }

  @override
  Future<({int checked, int linked})> relinkIngredients() async {
    relinks++;
    return (checked: 5, linked: 2);
  }

  @override
  Future<({String ingredients, String aliases})> addedIngredientRows() async =>
      (ingredients: '| 289 | Daun salam | Rempah | — | — | — |', aliases: '');

  List<CatalogueMaker> makerList = const [
    CatalogueMaker(id: 1, name: 'Faiza Marketing', brands: 1),
  ];
  List<CatalogueBrand> brandList = const [
    CatalogueBrand(
      id: 1,
      name: 'Faiza',
      makerId: 1,
      maker: 'Faiza Marketing',
      country: 'Malaysia',
      products: 3,
    ),
  ];
  List<CatalogueProduct> productList = const [
    CatalogueProduct(
      id: 1,
      name: 'Beras Faiza 5kg',
      ingredient: 'Beras putih',
      brandId: 1,
      brand: 'Faiza',
      size: 5,
      unit: 'kg',
    ),
  ];
  final catalogueQueries = <(String, String?)>[];
  final savedRows = <(String, int?, Map<String, Object?>)>[];
  final deletedRows = <(String, int)>[];

  @override
  Future<CataloguePage<CatalogueMaker>> makers({
    String? query,
    int offset = 0,
  }) async {
    catalogueQueries.add(('makers', query));
    return (items: makerList, next: null);
  }

  @override
  Future<(CataloguePage<CatalogueBrand>, List<String>)> brands({
    String? query,
    int offset = 0,
  }) async {
    catalogueQueries.add(('brands', query));
    return ((items: brandList, next: null), const ['Malaysia', 'Thailand']);
  }

  @override
  Future<(CataloguePage<CatalogueProduct>, List<String>)> products({
    String? query,
    int offset = 0,
  }) async {
    catalogueQueries.add(('products', query));
    return ((items: productList, next: null), const ['kg', 'L']);
  }

  @override
  Future<void> saveMaker({int? id, required String name}) async {
    if (name.toLowerCase() == 'taken') {
      throw const ApiException('name_taken', status: 409);
    }
    savedRows.add(('makers', id, {'name': name}));
    if (id == null) {
      makerList = [
        ...makerList,
        CatalogueMaker(id: 800 + makerList.length, name: name),
      ];
    }
  }

  @override
  Future<void> saveBrand({
    int? id,
    required String name,
    int? makerId,
    String? country,
  }) async {
    savedRows.add((
      'brands',
      id,
      {'name': name, 'makerId': makerId, 'country': country},
    ));
    if (id == null) {
      brandList = [
        ...brandList,
        CatalogueBrand(id: 900 + brandList.length, name: name),
      ];
    }
  }

  @override
  Future<void> saveProduct({
    int? id,
    required String name,
    String? ingredient,
    int? brandId,
    double? size,
    String? unit,
  }) async => savedRows.add((
    'products',
    id,
    {
      'name': name,
      'ingredient': ingredient,
      'brandId': brandId,
      'size': size,
      'unit': unit,
    },
  ));

  @override
  Future<void> deleteCatalogueRow(String kind, int id) async =>
      deletedRows.add((kind, id));

  @override
  Future<({String makers, String brands, String products})>
  catalogueRows() async =>
      (makers: '| 122 | Kilang Baru |', brands: '', products: '');
}
