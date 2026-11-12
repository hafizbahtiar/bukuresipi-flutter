/// A post the user shared, as the API reads it. [status]: pending | processing | done | failed.
/// [kind]: unknown | restaurant | recipe | other.
class Share {
  const Share({
    required this.id,
    required this.status,
    required this.kind,
    this.placeId,
    this.recipeId,
    this.gaps = const [],
    this.error,
    this.platform,
    this.attempts = 0,
  });

  final String id;
  final String status;
  final String kind;
  final String? placeId;
  final String? recipeId;
  final List<String> gaps;
  final String? error;

  /// tiktok | instagram | facebook | youtube | google_maps | web; null = a screenshot.
  final String? platform;

  /// Read attempts so far (the server tries up to 3 times).
  final int attempts;

  bool get isFinished => status == 'done' || status == 'failed';

  /// Finished without anything read from it (the book says so, with a hint to share a screenshot).
  /// Why it stopped: the server's error code, else its gaps ("unreadable").
  String get reason => error ?? gaps.join(', ');

  bool get couldNotRead => status == 'failed' || gaps.contains('unreadable');

  /// Read fine, but the post holds neither a recipe nor a place to eat.
  bool get nothingFound =>
      status == 'done' && placeId == null && recipeId == null && !couldNotRead;
}
