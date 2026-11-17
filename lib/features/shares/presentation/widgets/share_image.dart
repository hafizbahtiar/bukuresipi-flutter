import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/image_constant.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../places/domain/place.dart';
import '../../../places/presentation/places_controller.dart';
import '../../../recipes/domain/recipe.dart';
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
/// a share every time, so a list looks hand-pasted, not random). Takes no space while loading, or with no photo unless
/// it is a recipe's ([drawing]: the cooking drawing instead).
class SharePhoto extends StatefulWidget {
  /// [drawing]: with no photo, the cooking drawing in its place (recipes); else nothing (places).
  const SharePhoto(
    this.shareId, {
    super.key,
    this.size = 52,
    this.drawing = false,
  }) : recipeId = null,
       placeId = null,
       fallbackShareId = null;

  /// A recipe with no photo at all (typed, or its share's photo is gone): the cooking drawing, taped in the same way.
  const SharePhoto.placeholder({super.key, this.size = 52})
    : shareId = '',
      recipeId = null,
      placeId = null,
      fallbackShareId = null,
      drawing = true;

  /// A recipe's own cover photo ([cover] = its cover id) in place of a share's; [fallbackShareId] if it won't load.
  const SharePhoto.cover(
    String this.recipeId,
    String cover, {
    super.key,
    this.size = 52,
    this.fallbackShareId,
  }) : shareId = cover,
       placeId = null,
       drawing = true;

  /// A restaurant's chosen cover ([cover] = its cover id) in place of a share's; [fallbackShareId] if it won't load.
  const SharePhoto.place(
    String this.placeId,
    String cover, {
    super.key,
    this.size = 52,
    this.fallbackShareId,
  }) : shareId = cover,
       recipeId = null,
       drawing = false;

  /// The share id, or the cover id when [recipeId] or [placeId] is set.
  final String shareId;
  final String? recipeId;
  final String? placeId;
  final String? fallbackShareId;
  final double size;
  final bool drawing;

  @override
  State<SharePhoto> createState() => _SharePhotoState();
}

class _SharePhotoState extends State<SharePhoto> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() async {
    if (widget.shareId.isEmpty) return null;
    final shares = context.read<ShareRepository>();
    final cover = switch ((widget.recipeId, widget.placeId)) {
      (final recipe?, _) => context.read<RecipesController>().cover(
        recipe,
        widget.shareId,
      ),
      (_, final place?) => context.read<PlacesController>().restaurantCover(
        place,
        widget.shareId,
      ),
      _ => shares.image(widget.shareId),
    };
    final bytes = await cover.catchError((Object _) => null);
    if (bytes != null) return bytes;
    // A cover that won't load: the share's photo rather than nothing.
    final fallback = widget.fallbackShareId;
    return fallback == null
        ? null
        : shares.image(fallback).catchError((Object _) => null);
  }

  // A list reuses a row's state for another share (e.g. after a delete): load that share's image, not keep the old one.
  @override
  void didUpdateWidget(covariant SharePhoto old) {
    super.didUpdateWidget(old);
    if (old.shareId != widget.shareId ||
        old.recipeId != widget.recipeId ||
        old.placeId != widget.placeId ||
        old.fallbackShareId != widget.fallbackShareId) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, s) {
      final bytes = s.data;
      // Nothing while loading (no flash of the drawing before a real photo), nor for a place with no photo.
      if (bytes == null &&
          (!widget.drawing || s.connectionState != ConnectionState.done)) {
        return const SizedBox.shrink();
      }
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
                child: bytes == null
                    ? Image.asset(
                        ImageConstant.recipePlaceholder,
                        key: const ValueKey('recipe-placeholder'),
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.contain,
                        cacheWidth: (widget.size * 3).round(),
                        excludeFromSemantics: true,
                      )
                    : Image.memory(
                        bytes,
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.cover,
                        // decode small: a list of full-size photos is a lot of memory
                        cacheWidth: (widget.size * 3).round(),
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

/// A saved place's snapshot: the restaurant's chosen cover first (as the Home feed), else its share's photo.
SharePhoto? placePhoto(Place place, {double size = 52}) =>
    switch ((place.restaurant.cover, place.shareId)) {
      (final cover?, final share) => SharePhoto.place(
        place.restaurant.id,
        cover,
        size: size,
        fallbackShareId: share,
      ),
      (null, final share?) => SharePhoto(share, size: size),
      _ => null,
    };

/// A recipe's snapshot: its own cover first, else its share's photo, else the cooking drawing.
SharePhoto recipeSnapshot(Recipe recipe) =>
    switch ((recipe.cover, recipe.shareId)) {
      (final cover?, final share) => SharePhoto.cover(
        recipe.id,
        cover,
        fallbackShareId: share,
      ),
      (null, final share?) => SharePhoto(share, drawing: true),
      _ => const SharePhoto.placeholder(),
    };

/// A share's photo, a recipe's cover ([recipeId]) or a restaurant's cover ([placeId]), filling its box
/// (BoxFit.cover). [fallback] shows while loading, when there is none, or on error. For cards (Home feed); the list
/// rows use [SharePhoto].
class ShareFill extends StatefulWidget {
  const ShareFill({
    super.key,
    required this.id,
    this.recipeId,
    this.placeId,
    required this.fallback,
    this.cacheWidth = 600,
  });

  /// The share id, or the cover id when [recipeId] or [placeId] is set.
  final String id;
  final String? recipeId;
  final String? placeId;
  final Widget fallback;

  /// Decoded at this width: a card is at most ~240 dp wide (600); a page's header photo is the screen's width.
  final int cacheWidth;

  @override
  State<ShareFill> createState() => _ShareFillState();
}

class _ShareFillState extends State<ShareFill> {
  /// Photos already loaded this run, so a new ShareFill of one (a page's header after the card's hero flies there)
  /// draws it in its first frame instead of the fallback for a frame. The bytes are also in the repositories' caches.
  // shortcut: unbounded for the run's photos seen (~100 KB-1 MB each); bound it if a long session ever matters.
  static final _ready = <String, Uint8List>{};

  String get _key => '${widget.recipeId}/${widget.placeId}/${widget.id}';

  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => _fetch().then((b) {
    if (b != null) _ready[_key] = b;
    return b;
  });

  Future<Uint8List?> _fetch() => switch ((widget.recipeId, widget.placeId)) {
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
        old.placeId != widget.placeId) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    initialData: _ready[_key],
    builder: (context, s) => switch (s.data) {
      final bytes? => Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => widget.fallback,
      ),
      null => widget.fallback,
    },
  );
}
