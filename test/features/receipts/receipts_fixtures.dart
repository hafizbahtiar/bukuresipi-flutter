import 'dart:typed_data';

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
}) => Receipt(
  id: id,
  status: status,
  shop: 'Port Lepak Sentul',
  place: place,
  visitedAt: DateTime(2026, 11, 8, 20, 41),
  totalSen: totalSen,
  gaps: gaps,
  items: items,
  hasImage: status != 'saved',
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
  }) async {
    confirmed.add((
      id: id,
      totalSen: totalSen,
      visitedAt: visitedAt,
      branchId: branchId,
    ));
    final r = answers.last;
    return Receipt(
      id: id,
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

  @override
  Future<ReceiptStats> stats({int months = 12}) async => stats_;
}
