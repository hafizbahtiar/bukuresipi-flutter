import 'dart:typed_data';

import 'einvoice_link.dart';
import 'receipt.dart';

/// Throws ApiException (codes: invalid_image, duplicate_receipt (confirm: `existingId` = the saved one; [update] then
/// gives it this read's items and charges), receipt_limit, not_ready, place_required, not_found).
abstract interface class ReceiptsRepository {
  /// Uploads a photo (a local JPEG path), with its e-invoice QR link when the phone can read one; the server starts
  /// reading it. Returns the receipt id.
  Future<String> upload(String path);

  /// "I've requested the e-invoice": no reminder (false = not after all).
  Future<void> setEinvoiceDone(String id, bool done);

  /// Reads the e-invoice QR in a photo of it ([path]) and saves its link on the receipt. false = no QR link found.
  Future<bool> addEinvoiceFromPhoto(String id, String path);

  /// Google's live QR scanner, then saves the link on the receipt. [EinvoiceScan.unavailable] = this phone has no
  /// scanner: the caller falls back to a photo ([addEinvoiceFromPhoto]).
  Future<EinvoiceScan> scanEinvoice(String id);
  Future<Receipt> get(String id);

  /// [place] = only the saved visits at that place (its id), up to [limit].
  Future<({List<Receipt> items, String? next})> list({
    String? cursor,
    String? place,
    int? limit,
  });

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

  /// Today's calories (Malaysia day) from saved receipts and meals, against the user's target, with the day's eaten lines.
  Future<DailyCalories> calories();

  /// The last [days] Malaysia days of calories, oldest first, against the target (the chart).
  Future<CalorieDays> calorieDays({int days = 30});

  /// The dishes in a meal photo (a local JPEG path) with servings and per-serving numbers; nothing is saved and the
  /// photo is not kept. Codes: meal_limit, not_food, ai_unavailable, invalid_image.
  Future<List<MealItem>> estimateMeal(String path);

  /// Saves the dishes the user confirmed ([MealItem.name] and [MealItem.eaten] only).
  Future<void> saveMeal(DateTime eatenAt, List<MealItem> items);

  /// Replaces a saved meal's time and dishes (code: not_found).
  Future<void> replaceMeal(String id, DateTime eatenAt, List<MealItem> items);
  Future<void> removeMeal(String id);

  /// The receipt's split (empty [ReceiptSplit.people] = none). Codes: not_ready, not_found.
  Future<ReceiptSplit> split(String id);

  /// Replaces the split: the server computes the shares and sets the calorie ticks from "Me"'s lines.
  /// Codes: invalid_split, not_ready, not_found.
  Future<ReceiptSplit> saveSplit(
    String id, {
    required List<SplitPerson> people,
    required List<SplitPortion> portions,
  });

  /// Removes the split; the calorie ticks stay as they last were.
  Future<void> clearSplit(String id);
}
