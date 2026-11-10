/// A photographed restaurant receipt: totals and its item lines. The server reads it ([status] 'reading'), the user checks it
/// ('review') and saves it ('saved'); 'failed' = unreadable. The photo exists only until saved ([hasImage]).
class Receipt {
  const Receipt({
    required this.id,
    required this.status,
    this.shop,
    this.place,
    this.visitedAt,
    this.totalSen,
    this.gaps = const [],
    this.items = const [],
    this.charges = const [],
    this.hasImage = false,
    this.reason,
    this.eatenKcal = 0,
    this.hasEstimate = false,
    this.unknownEaten = 0,
    this.caloriesPending = false,
    this.hasSplit = false,
  });

  final String id;
  final String status;
  final String? shop;
  final ReceiptPlace? place;

  /// Local time (the API sends UTC).
  final DateTime? visitedAt;
  final int? totalSen;

  /// What the reader was unsure of: 'shop', 'date', 'total', 'totals_mismatch'.
  final List<String> gaps;

  /// The lines as printed, in order (the detail only; a list row has none).
  final List<ReceiptItem> items;

  /// The bill's lines between the items and the total, in bill order (the detail only).
  final List<ReceiptCharge> charges;
  final bool hasImage;

  /// Why it failed: 'not_restaurant' = refused (a grocery or petrol receipt), null = unreadable.
  final String? reason;

  /// kcal of the ticked lines (the detail only); [hasEstimate] = one of them is an AI estimate; [unknownEaten] =
  /// ticked lines with no calories; [caloriesPending] = the server is still matching the lines to dishes.
  final int eatenKcal;
  final bool hasEstimate;
  final double unknownEaten;
  final bool caloriesPending;

  /// A split bill exists, so the calories follow what is assigned to "Me" (the ticks are not edited here).
  final bool hasSplit;

  bool get notRestaurant => reason == 'not_restaurant';
  bool get reading => status == 'reading';
  bool get inReview => status == 'review';
  bool get saved => status == 'saved';
  bool get failed => status == 'failed';
}

/// One printed line: [quantity] null = not printed; [amountSen] = the whole line (negative for a discount);
/// [kcal] = one serving's calories (null = unknown), [kcalSource] 'table' | 'ai' (an AI estimate); [eaten] = how
/// many the user ate (0..quantity, or 0..1 when no quantity is printed).
typedef ReceiptItem = ({
  String name,
  double? quantity,
  int? amountSen,
  int? kcal,
  String? kcalSource,
  double eaten,
});

/// One eaten line of a day's receipt: [eaten] servings at [kcal] each ([kcalSource] 'table' | 'ai').
typedef DayItem = ({String name, double eaten, int? kcal, String? kcalSource});

/// A saved receipt with something eaten on [DailyCalories]'s day.
typedef DayReceipt = ({
  String id,
  String? shop,
  DateTime visitedAt,
  int eatenKcal,
  List<DayItem> items,
});

/// One day's calories from the user's saved receipts ([target] null = not set), with the day's eaten lines.
typedef DailyCalories = ({
  int eatenKcal,
  int? target,
  bool hasEstimate,
  double unknownEaten,
  List<DayReceipt> receipts,
});

/// One Malaysia day of the calories chart ([date] = local midnight).
typedef CalorieDay = ({
  DateTime date,
  int eatenKcal,
  bool hasEstimate,
  double unknownEaten,
});

/// The last 7 / 30 days of calories, oldest first, against [target].
class CalorieDays {
  const CalorieDays({required this.days, this.target});

  final List<CalorieDay> days;
  final int? target;
}

/// A person in a split bill ([paid] = their share is settled).
typedef SplitPerson = ({String name, bool paid});

/// One person's servings of one printed line ([position] = the item's index in [Receipt.items]).
typedef SplitPortion = ({int position, int person, double quantity});

/// What one person owes ([person] = their index in [ReceiptSplit.people]) and the lines they had.
typedef SplitShare = ({int person, int amountSen, List<String> lines});

/// The receipt's split bill, computed by the server: the shares are exact to [totalSen].
class ReceiptSplit {
  const ReceiptSplit({
    required this.people,
    required this.portions,
    required this.shares,
    this.totalSen,
  });

  final List<SplitPerson> people;
  final List<SplitPortion> portions;
  final List<SplitShare> shares;
  final int? totalSen;

  bool get exists => people.isNotEmpty;
}

/// [kind]: 'subtotal', 'discount', 'service', 'tax' (SST), 'other' ([name] as printed) or 'rounding';
/// [amountSen] negative when it takes money off.
typedef ReceiptCharge = ({String kind, String? name, int amountSen});

typedef ReceiptPlace = ({String restaurantId, String? branchId, String name});

/// The user's own visits and spend from saved receipts. [months]: 'YYYY-MM' with visits only (gaps left out).
class ReceiptStats {
  const ReceiptStats({
    required this.totalSen,
    required this.visits,
    required this.months,
    required this.places,
  });

  final int totalSen;
  final int visits;
  final List<({String month, int visits, int totalSen})> months;
  final List<({String restaurantId, String name, int visits, int totalSen})>
  places;
}

/// "RM 41.15" from sen; "-RM 2.00" for a discount.
String rm(int sen) {
  final a = sen.abs();
  return '${sen < 0 ? '-' : ''}RM ${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

/// "41.15" -> 4115; null when it is not an amount.
int? senOf(String text) {
  final m = RegExp(
    r'^\s*(?:RM\s*)?(\d{1,6})(?:[.,](\d{1,2}))?\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  return int.parse(m[1]!) * 100 + int.parse((m[2] ?? '0').padRight(2, '0'));
}
