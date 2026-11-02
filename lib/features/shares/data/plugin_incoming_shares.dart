import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../presentation/share_intake.dart';

/// The OS share sheet (Android intents / iOS share extension) via receive_sharing_intent.
class PluginIncomingShares implements IncomingShares {
  final _plugin = ReceiveSharingIntent.instance;

  static List<Incoming> _map(List<SharedMediaFile> files) => [
    for (final f in files)
      switch (f.type) {
        SharedMediaType.image => Incoming.image(f.path),
        SharedMediaType.text => Incoming.text(f.path),
        SharedMediaType.url => Incoming.url(f.path),
        SharedMediaType.video ||
        SharedMediaType.file => const Incoming.unsupported(),
      },
  ];

  @override
  Future<List<Incoming>> initial() async =>
      _map(await _plugin.getInitialMedia());

  @override
  Stream<List<Incoming>> get stream => _plugin.getMediaStream().map(_map);

  @override
  void reset() => _plugin.reset();
}
