/// A post the user shared, as the API reads it. [status]: pending | processing | done | failed.
/// [kind]: unknown | restaurant | recipe | other.
class Share {
  const Share({
    required this.id,
    required this.status,
    required this.kind,
    this.restaurantId,
    this.gaps = const [],
    this.error,
  });

  final String id;
  final String status;
  final String kind;
  final String? restaurantId;
  final List<String> gaps;
  final String? error;

  bool get isFinished => status == 'done' || status == 'failed';

  /// Finished without anything read from it (the book says so, with a hint to share a screenshot).
  bool get couldNotRead => status == 'failed' || gaps.contains('unreadable');
}
