import '../../places/domain/place.dart';

class OwnerStats {
  const OwnerStats({
    required this.usersTotal,
    required this.usersNewThisWeek,
    required this.sharesToday,
    required this.failedToday,
    required this.meters,
    this.reportsOpen = 0,
    this.reportsReady = 0,
    this.reviewReportsOpen = 0,
    this.ratingBursts = 0,
    this.testers = 0,
  });

  final int usersTotal;
  final int usersNewThisWeek;
  final int sharesToday;

  /// Failed, or done with a gap (unreadable, branches pending...).
  final int failedToday;
  final List<Meter> meters;

  /// Community report tickets: open, and open ones that reached the threshold.
  final int reportsOpen;
  final int reportsReady;
  final int reviewReportsOpen;

  /// Branches rated by several new accounts this week.
  final int ratingBursts;

  /// Website signups for the Android closed test.
  final int testers;

  OwnerStats withMeter(Meter m) => OwnerStats(
    usersTotal: usersTotal,
    usersNewThisWeek: usersNewThisWeek,
    sharesToday: sharesToday,
    failedToday: failedToday,
    meters: [for (final x in meters) x.code == m.code ? m : x],
    reportsOpen: reportsOpen,
    reportsReady: reportsReady,
    reviewReportsOpen: reviewReportsOpen,
    ratingBursts: ratingBursts,
    testers: testers,
  );
}

/// A website signup for the Android closed test (a Google account email, pasted into the Play Console).
class Tester {
  const Tester({
    required this.email,
    required this.lang,
    required this.joinedAt,
    this.invitedAt,
    this.emailStatus,
  });

  final String email;
  final String lang;
  final DateTime joinedAt;

  /// When the owner pressed Done (the invite email went out); null = not invited yet.
  final DateTime? invitedAt;

  /// Resend's last event for the invite: sent, delivered, delivery_delayed, bounced, complained, opened, clicked.
  final String? emailStatus;
}

/// A branch rated by several brand-new accounts in one week: maybe fake accounts. [ratings]: every rating on it this
/// week, newest first.
class RatingBurst {
  const RatingBurst({
    required this.branchId,
    required this.restaurant,
    this.label,
    required this.newAccounts,
    required this.ratings,
  });

  final String branchId;
  final String restaurant;
  final String? label;
  final int newAccounts;
  final List<BurstRating> ratings;
}

class BurstRating {
  const BurstRating({
    required this.id,
    required this.stars,
    this.text,
    required this.hidden,
    required this.createdAt,
    required this.email,
    required this.joinedAt,
    required this.emailVerified,
  });

  final String id;
  final int stars;
  final String? text;
  final bool hidden;
  final DateTime createdAt;
  final String email;
  final DateTime joinedAt;
  final bool emailVerified;
}

/// A recipe the owner hid from Community. [public] false = its author has since made it private or family only.
class HiddenRecipe {
  const HiddenRecipe({
    required this.id,
    required this.name,
    this.owner,
    required this.public,
    required this.hiddenAt,
  });

  final String id;
  final String name;
  final String? owner;
  final bool public;
  final DateTime hiddenAt;
}

/// A review the owner hid. [text] null = its author removed it; the hide still applies to their next one.
class HiddenReview {
  const HiddenReview({
    required this.id,
    required this.stars,
    this.text,
    required this.author,
    required this.place,
    required this.hiddenAt,
  });

  final String id;
  final int stars;
  final String? text;
  final String author;
  final String place;
  final DateTime hiddenAt;
}

class ReviewReportGroup {
  const ReviewReportGroup({
    required this.reviewId,
    required this.stars,
    required this.text,
    required this.author,
    required this.hidden,
    required this.createdAt,
    required this.count,
    required this.reasons,
    required this.updatedAt,
    this.latestNote,
  });

  final String reviewId;
  final int stars;
  final String text;
  final String author;
  final bool hidden;
  final DateTime createdAt;
  final int count;
  final List<String> reasons;
  final String? latestNote;
  final DateTime updatedAt;
}

class ReportValue {
  const ReportValue({this.lat, this.lng, this.value});

  final double? lat;
  final double? lng;
  final String? value;

  String get label {
    if (lat != null && lng != null) {
      return '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}';
    }
    return value ?? '—';
  }
}

/// One owner report ticket: open, or closed as applied/rejected.
class ReportTicket {
  const ReportTicket({
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.field,
    required this.count,
    required this.threshold,
    required this.status,
    required this.ready,
    required this.updatedAt,
    this.targetLabel,
    this.current = const ReportValue(),
    this.proposed,
    this.latestNote,
    this.verifiedAt,
  });

  final String targetType;
  final String targetId;
  final String targetName;
  final String? targetLabel;
  final String field;
  final int count;
  final int threshold;
  final ReportValue current;
  final ReportValue? proposed;
  final String status;
  final bool ready;
  final String? latestNote;
  final DateTime? verifiedAt;
  final DateTime updatedAt;

  String get title => targetLabel == null || targetLabel == targetName
      ? targetName
      : '$targetName · $targetLabel';
}

/// One outside service (system_subscription): calls this month vs. the cap. Off or at the cap = calls refused.
class Meter {
  const Meter({
    required this.code,
    required this.name,
    required this.used,
    required this.cap,
    required this.active,
    this.vendorUrl,
    this.period = 'month',
  });

  final String code;
  final String name;
  final int used;
  final int cap;
  final bool active;
  final String? vendorUrl;

  /// 'day' or 'month': what [cap] and [used] count.
  final String period;

  /// 0..1 of the cap used (1 when the cap is 0).
  double get share => cap <= 0 ? 1 : (used / cap).clamp(0, 1).toDouble();
}

class OwnerUser {
  const OwnerUser({
    required this.id,
    required this.email,
    required this.role,
    required this.verified,
    required this.createdAt,
    required this.shares,
    this.ban,
  });

  final String id;
  final String email;
  final String role;
  final bool verified;
  final DateTime createdAt;
  final int shares;

  /// The ban in force; [until] null = for good. null = not banned.
  final ({DateTime? until, String? reason})? ban;
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

/// A pinned branch on the owner's map (GET /owner/places): every restaurant, not only nearby. Counts, no names.
class OwnerPlace {
  const OwnerPlace({
    required this.branchId,
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.savers,
    this.label,
    this.address,
    this.city,
    this.state,
    this.pinSource,
  });

  final String branchId;
  final String placeId;
  final String name;
  final String? label;
  final String? address;
  final String? city;
  final String? state;
  final double lat;
  final double lng;
  final String? pinSource;
  final int savers;

  /// As the place screens' branch, for the shared edit sheet.
  Branch get branch => Branch(
    id: branchId,
    label: label,
    address: address,
    city: city,
    state: state,
    lat: lat,
    lng: lng,
    pinSource: pinSource,
  );
}

/// Owner > Ingredient gaps: recipe and shopping lines no catalogue name or alias matched, grouped by what they name
/// ([key], amount and unit off); [sample] = one line as written.
/// A kind of a food the AI named ("mee" -> Mee kuning, Mee sua). [ingredient] = ours it is, null = new;
/// [category] one of ours or null. Nothing saved.
typedef IngredientType = ({String name, String? category, String? ingredient});

/// A row of Owner > Ingredients and other names: [aliases] = how many other names it has.
typedef IngredientRow = ({int id, String name, String? category, int aliases});

/// One ingredient's page: its other names (lowercase, A-Z), the lines it links, and up to 8 that may be the same food.
typedef IngredientDetail = ({
  int id,
  String name,
  String? category,
  List<String> aliases,
  int recipeLines,
  int shoppingLines,
  List<({int id, String name, String? category})> similar,
});

/// The AI's answer for an unknown line: its name, the catalogue ingredient it is (null = new), a category of ours, and
/// the other kinds of that food (ours or new).
typedef GapSuggestion = ({
  String? name,
  String? ingredient,
  String? category,
  List<IngredientType> types,
});

/// A message the owner sent: [to] = the user's email, null = everyone. [pending] = its pushes are still going out.
typedef SentMessage = ({
  int id,
  String title,
  String body,
  String? to,
  int pushSent,
  int pushTotal,
  bool pending,
  String kind, // 'message' or 'update' (a tap opens Play)
  String? image, // the photo's public link
  DateTime createdAt,
});

class IngredientGap {
  const IngredientGap({
    required this.key,
    required this.sample,
    required this.recipeLines,
    required this.shoppingLines,
  });

  final String key;
  final String sample;
  final int recipeLines;
  final int shoppingLines;
}

/// Owner > Catalogue rows. [id]s are the server's internal ones (owner only).
class CatalogueMaker {
  const CatalogueMaker({required this.id, required this.name, this.brands = 0});

  final int id;
  final String name;
  final int brands;
}

class CatalogueBrand {
  const CatalogueBrand({
    required this.id,
    required this.name,
    this.makerId,
    this.maker,
    this.country,
    this.products = 0,
  });

  final int id;
  final String name;
  final int? makerId;
  final String? maker;
  final String? country;
  final int products;
}

class CatalogueProduct {
  const CatalogueProduct({
    required this.id,
    required this.name,
    this.ingredient,
    this.brandId,
    this.brand,
    this.size,
    this.unit,
  });

  final int id;
  final String name;

  /// A catalogue ingredient name.
  final String? ingredient;
  final int? brandId;
  final String? brand;
  final double? size;
  final String? unit;
}

/// One page of a catalogue list; [next] = the offset of the next page, null at the end.
typedef CataloguePage<T> = ({List<T> items, int? next});

/// An alias the AI proposed for a catalogue [ingredient]; [lines] = unlinked lines it would link now.
typedef AliasSuggestion = ({String ingredient, String alias, int lines});

/// A product form filled from a barcode, a store link or a name (nothing saved). [brandIsNew]: the catalogue has no
/// such brand yet; [aiIngredient]: the AI named the ingredient; [source]: the page the fields came from; [maker]: a
/// new brand's maker as a page names it (its country when the page says), null = not found; [similar] = may be
/// this product already.
typedef ProductFill = ({
  String name,
  String? brand,
  bool brandIsNew,
  double? size,
  String? unit,
  String? ingredient,
  bool aiIngredient,
  String source,
  ({String name, String? country, String source})? maker,

  /// Catalogue products that may be this one: edit one of them rather than add it again.
  List<CatalogueProduct> similar,
});

/// A brand or product authors asked for from recipe lines, grouped by name (Owner > Catalogue > Suggested).
typedef CatalogueSuggestion = ({
  String name,
  String? ingredient,
  int recipes,
  String sample,
});

/// Owner > AI: which provider, model and reasoning level ('off' | 'low' | 'medium' | 'high' | 'max') a use gets.
typedef AiSetting = ({String provider, String model, String reasoning});

/// A model the server offers, the levels it takes, and whether it reads photos.
typedef AiModel = ({
  String id,
  String name,
  List<String> reasoning,
  bool images,
});

/// [configured] = its key is set on the server.
typedef AiProvider = ({
  String id,
  String name,
  bool configured,
  List<AiModel> models,
});

/// One AI use: [budget] = runs inside a share or receipt run (thinking can make it fail), [images] = sends photos,
/// [setting] null = it follows the default.
typedef AiUse = ({String id, bool budget, bool images, AiSetting? setting});

typedef AiSettings = ({
  List<AiProvider> providers,
  AiSetting defaults,
  List<AiUse> uses,
});
