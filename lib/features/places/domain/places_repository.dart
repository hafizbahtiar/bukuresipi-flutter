import 'place.dart';

/// The user's saved places. Every method throws ApiException (core/network) on failure.
abstract interface class PlacesRepository {
  /// Newest first.
  Future<List<Place>> list();

  /// Empty or blank [note] clears it.
  Future<void> updateNote(String id, String? note);

  /// Takes the place off this user's map (the restaurant stays for others).
  Future<void> remove(String id);
}
