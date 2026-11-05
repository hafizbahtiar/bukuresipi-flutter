import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/log.dart';
import '../domain/share.dart';
import '../domain/share_repository.dart';

/// Shares from the last day, for the book: the ones still being read, and the ones that could not be read. While any
/// is being read it looks again every [every]; when one finishes, [onFinished] reloads the book.
class RecentShares extends ChangeNotifier {
  RecentShares(
    this._repo, {
    required this.onFinished,
    this.every = const Duration(seconds: 5),
  });

  final ShareRepository _repo;
  final Future<void> Function() onFinished;
  final Duration every;
  List<Share> _shares = const [];
  Timer? _next;
  int _generation = 0;
  String _logged = '';

  List<Share> get reading => [
    for (final s in _shares)
      if (!s.isFinished) s,
  ];

  /// Could not be read, or read with nothing in it: the book says why.
  List<Share> get failed => [
    for (final s in _shares)
      if (s.couldNotRead || s.nothingFound) s,
  ];

  /// Recipe / restaurant ids that just finished reading: the book highlights them as they arrive.
  final Set<String> _fresh = {};
  Timer? _unfresh;
  bool isFresh(String id) => _fresh.contains(id);

  Future<void> load() async {
    _next?.cancel();
    final wasReading = {for (final s in reading) s.id};
    final generation = _generation;
    try {
      final shares = await _repo.recent();
      if (generation != _generation) {
        return; // signed out meanwhile: no data, no next poll
      }
      _shares = shares;
      // `flutter run` console: each share's state, once per change (polling repeats the same list).
      final now = [
        for (final s in _shares)
          'share ${s.id}: ${s.status}, kind ${s.kind}, ${s.reason.isEmpty ? 'ok' : s.reason}',
      ].join('\n');
      if (now != _logged) log(_logged = now);
    } catch (_) {
      // Offline for a moment: the next load tries again.
    }
    if (generation != _generation) return;
    notifyListeners();
    final finished = [
      for (final s in _shares)
        if (s.isFinished && wasReading.contains(s.id)) s,
    ];
    if (finished.isNotEmpty) {
      _fresh.addAll([
        for (final s in finished) ?s.restaurantId,
        for (final s in finished) ?s.recipeId,
      ]);
      _unfresh?.cancel();
      _unfresh = Timer(const Duration(seconds: 6), _fresh.clear);
      await onFinished();
    }
    if (reading.isNotEmpty) _next = Timer(every, load);
  }

  /// Throws ApiException; the row shows it.
  Future<void> retry(String id) async {
    await _repo.retry(id);
    await load();
  }

  /// Throws ApiException; the row shows it.
  Future<void> dismiss(String id) async {
    await _repo.dismiss(id);
    _shares = _shares.where((s) => s.id != id).toList();
    notifyListeners();
  }

  void clear() {
    _generation++;
    _next?.cancel();
    _fresh.clear();
    _shares = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _next?.cancel();
    _unfresh?.cancel();
    super.dispose();
  }
}
