import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';

/// The caller's family (or none). [onChanged] runs after joining or leaving: the book, recipes and lists change.
class FamilyController extends ChangeNotifier {
  FamilyController(this._repo, {this.onChanged});

  final FamilyRepository _repo;
  final Future<void> Function()? onChanged;
  Family? _family;
  bool _loaded = false;
  int _generation = 0;

  Family? get family => _family;
  bool get inFamily => _family != null;

  /// False until the first load finished.
  bool get loaded => _loaded;

  void clear() {
    _generation++;
    _family = null;
    _loaded = false;
    notifyListeners();
  }

  /// A failed load keeps what was there (the app works without a family).
  Future<void> load() async {
    final generation = _generation;
    try {
      final f = await _repo.get();
      if (generation != _generation) return;
      _family = f;
    } on ApiException {
      if (generation != _generation) return;
    }
    _loaded = true;
    notifyListeners();
  }

  void _set(Family? f) {
    _family = f;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _membershipChanged(Family? f) async {
    _set(f);
    await onChanged?.call();
  }

  // Every action throws ApiException; the page shows it.
  Future<void> create(String name) async =>
      _membershipChanged(await _repo.create(name));
  Future<void> rename(String name) async => _set(await _repo.rename(name));
  Future<InvitePreview> preview(String token) => _repo.preview(token);
  Future<void> join(String token) async =>
      _membershipChanged(await _repo.join(token));

  Future<void> leave() async {
    await _repo.leave();
    await _membershipChanged(null);
  }

  Future<({String url, DateTime expiresAt})> invite() async {
    final link = await _repo.invite();
    await load(); // the page shows "link works until"
    return link;
  }

  Future<void> stopInvite() async {
    await _repo.stopInvite();
    await load();
  }

  Future<void> removeMember(String userId) async {
    await _repo.removeMember(userId);
    await load();
  }

  Future<void> handOver(String userId) async =>
      _set(await _repo.handOver(userId));
}
