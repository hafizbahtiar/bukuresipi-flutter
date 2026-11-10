import 'dart:typed_data';

import 'receipt.dart';

/// Throws ApiException (codes: invalid_image, duplicate_receipt (confirm: `existingId` = the saved one; [update] then
/// gives it this read's items and charges), receipt_limit, not_ready, place_required, not_found).
abstract interface class ReceiptsRepository {
  /// Uploads a photo (a local JPEG path); the server starts reading it. Returns the receipt id.
  Future<String> upload(String path);
  Future<Receipt> get(String id);
  Future<({List<Receipt> items, String? next})> list({String? cursor});

  /// The user's check: their total and time win. [branchId] picks the place when the read found none.
  Future<Receipt> confirm(
    String id, {
    required int totalSen,
    required DateTime visitedAt,
    String? branchId,
    bool update = false,
  });
  Future<void> remove(String id);

  /// The photo while it exists (until saved); null = gone.
  Future<Uint8List?> image(String id);
  Future<ReceiptStats> stats({int months = 12});

  /// Ticks how many of line [position] the user ate (codes: too_many, not_ready, not_found).
  Future<void> setEaten(String id, int position, double eaten);

  /// Today's calories (Malaysia day) from saved receipts, against the user's target.
  Future<DailyCalories> calories();
}
