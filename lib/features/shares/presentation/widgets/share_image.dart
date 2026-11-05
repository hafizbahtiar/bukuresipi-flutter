import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/share_repository.dart';

/// The screenshot or post thumbnail behind a share. Takes no space while loading, when there is none, or on error.
class ShareImage extends StatefulWidget {
  const ShareImage(this.shareId, {super.key});

  final String shareId;

  @override
  State<ShareImage> createState() => _ShareImageState();
}

class _ShareImageState extends State<ShareImage> {
  late final Future<Uint8List?> _bytes = context
      .read<ShareRepository>()
      .image(widget.shareId)
      .catchError((Object _) => null);

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
