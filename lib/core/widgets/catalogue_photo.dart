import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../env/env.dart';
import '../theme/app_theme.dart';

/// A catalogue photo (a product's, or a brand's logo) by its id (GET /catalogue/photo/:id, no sign-in), square, kept on
/// disk: a new id per photo, so a cached one never goes stale. Loading or gone: a plain tile of the same size (a row
/// never jumps).
class CataloguePhoto extends StatelessWidget {
  const CataloguePhoto(this.id, {super.key, this.size = 40});

  final String id;
  final double size;

  static String url(String id) =>
      '${Env.apiBaseUrl}/api/v1/catalogue/photo/$id';

  @override
  Widget build(BuildContext context) {
    final blank = ColoredBox(
      color: Notebook.of(context).mist,
      child: SizedBox.square(dimension: size),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 5),
      // Product photos are at most 512 px (the owner's form; Open Food Facts' are 400): decoded as they are.
      child: ExtendedImage.network(
        url(id),
        cache: true,
        printError: false,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Loading or gone (offline, deleted): the blank tile.
        loadStateChanged: (s) =>
            s.extendedImageLoadState == LoadState.completed ? null : blank,
      ),
    );
  }
}
