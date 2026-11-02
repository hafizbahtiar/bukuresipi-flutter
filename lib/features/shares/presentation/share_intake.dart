import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/share_repository.dart';

enum IncomingKind { text, image, url, unsupported }

/// One item from the share sheet: text (often "look at this https://..."), an image file path, or a URL.
class Incoming {
  const Incoming.text(String this.value) : kind = IncomingKind.text;
  const Incoming.image(String this.value) : kind = IncomingKind.image;
  const Incoming.url(String this.value) : kind = IncomingKind.url;
  const Incoming.unsupported() : kind = IncomingKind.unsupported, value = null;

  final IncomingKind kind;
  final String? value;
}

/// Where shares come from (the OS share sheet in the app, a fake in tests).
abstract interface class IncomingShares {
  Future<List<Incoming>> initial();
  Stream<List<Incoming>> get stream;
  void reset();
}

sealed class ShareState {
  const ShareState();
}

class ShareIdle extends ShareState {
  const ShareIdle();
}

class ShareWaitingForLogin extends ShareState {
  const ShareWaitingForLogin();
}

class ShareSending extends ShareState {
  const ShareSending();
}

class ShareAccepted extends ShareState {
  const ShareAccepted(this.id);
  final String id;
}

class ShareFailed extends ShareState {
  const ShareFailed(this.code);
  final String code; // API error code, or no_link / unsupported
  bool get canRetry =>
      code == ApiException.network ||
      code == 'rate_limited' ||
      code == ApiException.unknown;
}

/// The first https link in shared text, without trailing punctuation.
String? firstLink(String text) {
  final m = RegExp(r'''https://[^\s<>"']+''').firstMatch(text);
  return m?.group(0)!.replaceFirst(RegExp(r'''[.,;:!?)\]]+$'''), '');
}

/// Takes what the user shares into the app and sends it to the API once they are signed in.
class ShareIntake extends ChangeNotifier {
  ShareIntake(this._source, this._repo, this._auth);

  final IncomingShares _source;
  final ShareRepository _repo;
  final AuthController _auth;
  StreamSubscription<List<Incoming>>? _sub;

  /// Set by the app: open the share screen.
  VoidCallback? onShow;

  ShareState _state = const ShareIdle();
  ShareState get state => _state;

  Incoming? _pending; // not sent yet (signed out, or sending)
  Incoming? _last; // for retry
  bool _sending = false;

  static const _ownHosts = {'bukuresipi.com', 'www.bukuresipi.com'};

  Future<void> start() async {
    _auth.addListener(_maybeSend);
    _accept(await _source.initial());
    _sub = _source.stream.listen(_accept);
  }

  void _set(ShareState s, {bool show = false}) {
    _state = s;
    notifyListeners();
    if (show) onShow?.call();
  }

  void _accept(List<Incoming> items) {
    if (items.isEmpty) return;
    _source.reset();
    final item = items.first;
    switch (item.kind) {
      case IncomingKind.url:
        // Android reports our own App Links (email links) here: those are routes, not shares.
        final uri = Uri.tryParse(item.value!);
        if (uri == null || _ownHosts.contains(uri.host)) return;
        _pending = item;
      case IncomingKind.text:
        final link = firstLink(item.value!);
        if (link == null) return _set(const ShareFailed('no_link'), show: true);
        _pending = Incoming.url(link);
      case IncomingKind.image:
        _pending = item;
      case IncomingKind.unsupported:
        return _set(const ShareFailed('unsupported'), show: true);
    }
    onShow?.call();
    _maybeSend();
  }

  /// Send again after a network error.
  void retry() {
    if (_last == null || _sending) return;
    _pending = _last;
    _maybeSend();
  }

  void dismiss() => _set(const ShareIdle());

  Future<void> _maybeSend() async {
    final item = _pending;
    if (item == null || _sending) return;
    if (_auth.status != AuthStatus.signedIn) {
      if (_state is! ShareWaitingForLogin) _set(const ShareWaitingForLogin());
      return;
    }
    _sending = true;
    _pending = null;
    _last = item;
    _set(const ShareSending());
    try {
      final id = item.kind == IncomingKind.image
          ? await _repo.submitImage(item.value!)
          : await _repo.submitLink(item.value!);
      _set(ShareAccepted(id), show: true);
    } catch (e) {
      _set(ShareFailed(ApiException.from(e).code), show: true);
    } finally {
      _sending = false;
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_maybeSend);
    _sub?.cancel();
    super.dispose();
  }
}
