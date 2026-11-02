import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/log.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/caption_reader.dart';
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
  ShareIntake(this._source, this._repo, this._auth, this._captions);

  final IncomingShares _source;
  final ShareRepository _repo;
  final AuthController _auth;
  final CaptionReader _captions;
  StreamSubscription<List<Incoming>>? _sub;

  /// Set by the app: open the share screen.
  VoidCallback? onShow;

  ShareState _state = const ShareIdle();
  ShareState get state => _state;

  final List<Incoming> _queue = [];
  Incoming? _last; // for retry
  bool _sending = false;

  static const _ownHosts = {'bukuresipi.com', 'www.bukuresipi.com'};

  /// Sites whose caption the API cannot read (TikTok's oEmbed gives none): read on the phone first.
  static bool _readOnPhone(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host == 'tiktok.com' || host.endsWith('.tiktok.com');
  }

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
    var queued = false;
    for (final item in items) {
      log('share in: ${item.kind.name} ${item.value ?? ''}');
      switch (item.kind) {
        case IncomingKind.url:
          // Android reports our own App Links (email links) here: those are routes, not shares.
          final uri = Uri.tryParse(item.value!);
          if (uri == null || _ownHosts.contains(uri.host)) continue;
          _queue.add(item);
          queued = true;
        case IncomingKind.text:
          final link = firstLink(item.value!);
          if (link == null) {
            log('share: no https link in the text');
            _set(const ShareFailed('no_link'), show: true);
            continue;
          }
          log('share: link $link');
          _queue.add(Incoming.url(link));
          queued = true;
        case IncomingKind.image:
          _queue.add(item);
          queued = true;
        case IncomingKind.unsupported:
          _set(const ShareFailed('unsupported'), show: true);
      }
    }
    if (!queued) return;
    onShow?.call();
    _maybeSend();
  }

  /// Send again after a network error.
  void retry() {
    if (_last == null || _sending) return;
    _queue.insert(0, _last!);
    _maybeSend();
  }

  void dismiss() => _set(const ShareIdle());

  Future<void> _maybeSend() async {
    if (_queue.isEmpty || _sending) return;
    if (_auth.status != AuthStatus.signedIn) {
      if (_state is! ShareWaitingForLogin) _set(const ShareWaitingForLogin());
      return;
    }
    _sending = true;
    final item = _queue.removeAt(0);
    _last = item;
    _set(const ShareSending());
    try {
      final String id;
      if (item.kind == IncomingKind.image) {
        id = await _repo.submitImage(item.value!);
      } else {
        final caption = _readOnPhone(item.value!)
            ? await _captions.read(item.value!).catchError((_) => null)
            : null;
        if (_readOnPhone(item.value!)) {
          log(
            'share: caption read on the phone, ${caption?.length ?? 0} chars',
          );
        }
        id = await _repo.submitLink(item.value!, caption: caption);
      }
      log('share: accepted, id $id');
      _set(ShareAccepted(id), show: true);
    } catch (e) {
      log('share: refused, ${ApiException.from(e).code}');
      _set(ShareFailed(ApiException.from(e).code), show: true);
    } finally {
      _sending = false;
      // A second share may have arrived while this one was sending: send it too.
      if (_queue.isNotEmpty && _auth.status == AuthStatus.signedIn) {
        unawaited(_maybeSend());
      }
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_maybeSend);
    _sub?.cancel();
    super.dispose();
  }
}
