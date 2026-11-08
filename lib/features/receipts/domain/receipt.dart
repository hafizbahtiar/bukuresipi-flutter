/// A photographed restaurant receipt (totals only). The server reads it ([status] 'reading'), the user checks it
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
    this.hasImage = false,
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
  final bool hasImage;

  bool get reading => status == 'reading';
  bool get inReview => status == 'review';
  bool get saved => status == 'saved';
  bool get failed => status == 'failed';
}

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

/// "RM 41.15" from sen.
String rm(int sen) =>
    'RM ${sen ~/ 100}.${(sen % 100).toString().padLeft(2, '0')}';

/// "41.15" -> 4115; null when it is not an amount.
int? senOf(String text) {
  final m = RegExp(
    r'^\s*(?:RM\s*)?(\d{1,6})(?:[.,](\d{1,2}))?\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  return int.parse(m[1]!) * 100 + int.parse((m[2] ?? '0').padRight(2, '0'));
}
