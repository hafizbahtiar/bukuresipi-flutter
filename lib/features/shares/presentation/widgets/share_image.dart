import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/share_repository.dart';

/// The screenshot or post thumbnail behind a share. Takes no space while loading, when there is none, or on error.
class ShareImage extends StatefulWidget {
  const ShareImage(this.shareId, {super.key});

  final String shareId;

  @override
  State<ShareImage> createState() => _ShareImageState();
}

class _ShareImageState extends State<ShareImage> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => context
      .read<ShareRepository>()
      .image(widget.shareId)
      .catchError((Object _) => null);

  // A list reuses a row's state for another share (e.g. after a delete): load that share's image, not keep the old one.
  @override
  void didUpdateWidget(covariant ShareImage old) {
    super.didUpdateWidget(old);
    if (old.shareId != widget.shareId) _bytes = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, s) => switch (s.data) {
      final bytes? => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      null => const SizedBox.shrink(),
    },
  );
}

/// A share's photo as a small snapshot taped into the book: white border, a strip of tape, a slight tilt (the same for
/// a share every time, so a list looks hand-pasted, not random). Takes no space while loading or when there is none.
class SharePhoto extends StatefulWidget {
  const SharePhoto(this.shareId, {super.key, this.size = 52});

  final String shareId;
  final double size;

  @override
  State<SharePhoto> createState() => _SharePhotoState();
}

class _SharePhotoState extends State<SharePhoto> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => context
      .read<ShareRepository>()
      .image(widget.shareId)
      .catchError((Object _) => null);

  // A list reuses a row's state for another share (e.g. after a delete): load that share's image, not keep the old one.
  @override
  void didUpdateWidget(covariant SharePhoto old) {
    super.didUpdateWidget(old);
    if (old.shareId != widget.shareId) _bytes = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, s) {
      final bytes = s.data;
      if (bytes == null) return const SizedBox.shrink();
      final nb = Notebook.of(context);
      final tilt = ((widget.shareId.hashCode % 5) - 2) * 0.025;
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 8),
        child: Transform.rotate(
          angle: tilt,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Notebook.light.paper,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.memory(
                  bytes,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  cacheWidth: (widget.size * 3).round(), // decode small: a list of full-size photos is a lot of memory
                  semanticLabel: null,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              Positioned(
                top: -6,
                child: Transform.rotate(
                  angle: -tilt * 3,
                  child: Container(
                    width: widget.size * 0.55,
                    height: 12,
                    decoration: BoxDecoration(
                      color: nb.kunyit.withValues(alpha: 0.55),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
