import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../places/presentation/places_controller.dart';
import '../../../recipes/presentation/recipes_controller.dart';
import '../../domain/share_repository.dart';

/// The screenshot or post thumbnail behind a share. Takes no space while loading, when there is none, or on error.
class ShareImage extends StatefulWidget {
  const ShareImage(this.shareId, {super.key, this.hero = false})
    : recipeId = null;

  /// A recipe's own cover photo ([cover] = its cover id) in place of a share's.
  const ShareImage.cover(
    String this.recipeId,
    String cover, {
    super.key,
    this.hero = false,
  }) : shareId = cover;

  /// The share id, or the cover id when [recipeId] is set.
  final String shareId;
  final String? recipeId;

  /// Edge to edge at the top of a page (4:3, square corners) instead of a framed photo in the text.
  final bool hero;

  @override
  State<ShareImage> createState() => _ShareImageState();
}

class _ShareImageState extends State<ShareImage> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => switch (widget.recipeId) {
    final recipe? => context.read<RecipesController>().cover(
      recipe,
      widget.shareId,
    ),
    null => context.read<ShareRepository>().image(widget.shareId),
  }.catchError((Object _) => null);

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
      final bytes? when widget.hero => AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
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
  const SharePhoto(this.shareId, {super.key, this.size = 52}) : recipeId = null;

  /// A recipe's own cover photo ([cover] = its cover id) in place of a share's.
  const SharePhoto.cover(
    String this.recipeId,
    String cover, {
    super.key,
    this.size = 52,
  }) : shareId = cover;

  /// The share id, or the cover id when [recipeId] is set.
  final String shareId;
  final String? recipeId;
  final double size;

  @override
  State<SharePhoto> createState() => _SharePhotoState();
}

class _SharePhotoState extends State<SharePhoto> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => switch (widget.recipeId) {
    final recipe? => context.read<RecipesController>().cover(
      recipe,
      widget.shareId,
    ),
    null => context.read<ShareRepository>().image(widget.shareId),
  }.catchError((Object _) => null);

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

/// A share's photo, a recipe's cover ([recipeId]) or a restaurant's cover ([restaurantId]), filling its box
/// (BoxFit.cover). [fallback] shows while loading, when there is none, or on error. For cards (Home feed); the list
/// rows use [SharePhoto].
class ShareFill extends StatefulWidget {
  const ShareFill({
    super.key,
    required this.id,
    this.recipeId,
    this.restaurantId,
    required this.fallback,
  });

  /// The share id, or the cover id when [recipeId] or [restaurantId] is set.
  final String id;
  final String? recipeId;
  final String? restaurantId;
  final Widget fallback;

  @override
  State<ShareFill> createState() => _ShareFillState();
}

class _ShareFillState extends State<ShareFill> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() =>
      switch ((widget.recipeId, widget.restaurantId)) {
        (final recipe?, _) => context.read<RecipesController>().cover(
          recipe,
          widget.id,
        ),
        (_, final r?) => context.read<PlacesController>().restaurantCover(
          r,
          widget.id,
        ),
        _ => context.read<ShareRepository>().image(widget.id),
      }.catchError((Object _) => null);

  @override
  void didUpdateWidget(covariant ShareFill old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id ||
        old.recipeId != widget.recipeId ||
        old.restaurantId != widget.restaurantId) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, s) => switch (s.data) {
      final bytes? => Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 600, // a card is at most ~240 dp wide
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => widget.fallback,
      ),
      null => widget.fallback,
    },
  );
}
