import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../auth_controller.dart';

/// A person's round picture, or the first letter of their [name] on a soft circle (none, loading, or not visible).
class Avatar extends StatefulWidget {
  const Avatar({
    super.key,
    required this.userId,
    required this.avatar,
    required this.name,
    this.size = 40,
  });

  final String userId;

  /// The avatar id; null = no picture.
  final String? avatar;
  final String? name;
  final double size;

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => switch (widget.avatar) {
    final a? =>
      context
          .read<AuthController>()
          .avatar(widget.userId, a)
          .catchError((Object _) => null),
    null => Future.value(null),
  };

  @override
  void didUpdateWidget(covariant Avatar old) {
    super.didUpdateWidget(old);
    if (old.avatar != widget.avatar || old.userId != widget.userId) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final letter = (widget.name?.trim().isNotEmpty ?? false)
        ? widget.name!.trim()[0].toUpperCase()
        : '?';
    final initial = CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: nb.mist,
      foregroundColor: nb.pandanDeep,
      child: Text(
        letter,
        style: nb.hand.copyWith(fontSize: widget.size * 0.55, height: 1),
      ),
    );
    return FutureBuilder(
      future: _bytes,
      builder: (context, s) => switch (s.data) {
        final bytes? => CircleAvatar(
          radius: widget.size / 2,
          backgroundColor: nb.mist,
          backgroundImage: ResizeImage(
            MemoryImage(bytes),
            width: (widget.size * 3).round(), // decode small
          ),
        ),
        null => initial,
      },
    );
  }
}
