import 'dart:async';

import 'package:flutter/foundation.dart';

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

  List<Share> get reading => [
    for (final s in _shares)
      if (!s.isFinished) s,
  ];
  List<Share> get failed => [
    for (final s in _shares)
      if (s.couldNotRead) s,
  ];

  Future<void> load() async {
    _next?.cancel();
    final wasReading = {for (final s in reading) s.id};
    try {
      _shares = await _repo.recent();
    } catch (_) {
      // Offline for a moment: the next load tries again.
    }
    notifyListeners();
    if (_shares.any((s) => s.isFinished && wasReading.contains(s.id))) {
      await onFinished();
    }
    if (reading.isNotEmpty) _next = Timer(every, load);
  }

  void clear() {
    _next?.cancel();
    _shares = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }
}
