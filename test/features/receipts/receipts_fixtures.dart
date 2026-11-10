import 'dart:typed_data';

import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipt.dart';
import 'package:bukuresipi_flutter/features/receipts/domain/receipts_repository.dart';

Receipt receipt({
  String id = 'r-1',
  String status = 'review',
  ReceiptPlace? place = (
    restaurantId: 'x',
    branchId: 'b-1',
    name: 'Port Lepak Sentul',
  ),
  int? totalSen = 4115,
  List<String> gaps = const [],
  List<ReceiptItem> items = const [],
  List<ReceiptCharge> charges = const [],
  String? reason,
  int eatenKcal = 0,
  bool hasEstimate = false,
  bool caloriesPending = false,
  bool hasSplit = false,
}) => Receipt(
  id: id,
  status: status,
  shop: 'Port Lepak Sentul',
  place: place,
  visitedAt: DateTime(2026, 11, 8, 20, 41),
  totalSen: totalSen,
  gaps: gaps,
  items: items,
  charges: charges,
  hasImage: status != 'saved',
  reason: reason,
  eatenKcal: eatenKcal,
  hasEstimate: hasEstimate,
  caloriesPending: caloriesPending,
  hasSplit: hasSplit,
);

class FakeReceipts implements ReceiptsRepository {
  /// What get() answers, in order; the last one repeats.
  List<Receipt> answers = [receipt()];
  ReceiptStats stats_ = const ReceiptStats(
    totalSen: 0,
    visits: 0,
    months: [],
    places: [],
  );
  List<Receipt> items = [];

  /// The saved receipt a confirm runs into (409 `duplicate_receipt`).
  String? duplicateOf;
  final uploaded = <String>[];
  final confirmed =
      <({String id, int totalSen, DateTime visitedAt, String? branchId})>[];
  final removed = <String>[];
  int gets = 0;

  @override
  Future<String> upload(String path) async {
    uploaded.add(path);
    return 'r-1';
  }

  @override
  Future<Receipt> get(String id) async =>
      answers[(gets++).clamp(0, answers.length - 1)];

  @override
  Future<({List<Receipt> items, String? next})> list({String? cursor}) async {
    // pageSize set = paged like the API: the cursor is the index to start at.
    final size = pageSize;
    if (size == null) return (items: items, next: null);
    final from = int.parse(cursor ?? '0');
    final end = (from + size).clamp(0, items.length);
    return (
      items: items.sublist(from, end),
      next: end < items.length ? '$end' : null,
    );
  }

  int? pageSize;

  @override
  Future<Receipt> confirm(
    String id, {
    required int totalSen,
    required DateTime visitedAt,
    String? branchId,
    bool update = false,
  }) async {
    if (duplicateOf != null && !update) {
      throw ApiException(
        'duplicate_receipt',
        status: 409,
        data: {'existingId': duplicateOf},
      );
    }
    confirmed.add((
      id: id,
      totalSen: totalSen,
      visitedAt: visitedAt,
      branchId: branchId,
    ));
    final r = answers.last;
    return Receipt(
      id: update ? duplicateOf! : id,
      status: 'saved',
      shop: r.shop,
      place: r.place,
      visitedAt: visitedAt,
      totalSen: totalSen,
      items: r.items,
    );
  }

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  Future<Uint8List?> image(String id) async => photo;

  /// The receipt photo [image] answers; null = none (the plain "Reading…" spinner).
  Uint8List? photo;

  int statCalls = 0;

  @override
  Future<ReceiptStats> stats({int months = 12}) async {
    statCalls++;
    return stats_;
  }

  final eaten = <({String id, int position, double eaten})>[];
  Object? eatenError;

  @override
  Future<void> setEaten(String id, int position, double eaten) async {
    if (eatenError != null) throw eatenError!;
    this.eaten.add((id: id, position: position, eaten: eaten));
  }

  DailyCalories today = (
    eatenKcal: 0,
    target: null,
    hasEstimate: false,
    unknownEaten: 0,
    receipts: const [],
  );

  @override
  Future<DailyCalories> calories() async => today;

  CalorieDays calorieDaysAnswer = const CalorieDays(days: [], target: null);
  final calorieDayRanges = <int>[];

  @override
  Future<CalorieDays> calorieDays({int days = 30}) async {
    calorieDayRanges.add(days);
    return calorieDaysAnswer;
  }

  ReceiptSplit splitAnswer = const ReceiptSplit(
    people: [],
    portions: [],
    shares: [],
    totalSen: 4115,
  );
  final savedSplits =
      <({String id, List<SplitPerson> people, List<SplitPortion> portions})>[];
  final cleared = <String>[];

  @override
  Future<ReceiptSplit> split(String id) async => splitAnswer;

  @override
  Future<ReceiptSplit> saveSplit(
    String id, {
    required List<SplitPerson> people,
    required List<SplitPortion> portions,
  }) async {
    savedSplits.add((id: id, people: people, portions: portions));
    splitAnswer = ReceiptSplit(
      people: people,
      portions: portions,
      shares: splitAnswer.shares,
      totalSen: splitAnswer.totalSen,
    );
    return splitAnswer;
  }

  @override
  Future<void> clearSplit(String id) async {
    cleared.add(id);
    splitAnswer = ReceiptSplit(
      people: const [],
      portions: const [],
      shares: const [],
      totalSen: splitAnswer.totalSen,
    );
  }
}
