import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../open_link.dart';
import '../theme/app_theme.dart';

/// An AI draft's photos from web pages (up to 3, side by side, 4:3): tap one to pick it as the cover, again to drop
/// it. Shared by the recipe and place drafts.
class DraftPhotos extends StatelessWidget {
  const DraftPhotos({
    super.key,
    required this.urls,
    required this.picked,
    required this.onPick,
  });

  final List<String> urls;
  final String? picked;

  /// The tapped photo, or null when the picked one is tapped again.
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.recipeAiDraftPhotos,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: nb.inkSoft),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (i, url) in urls.take(3).indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _photo(l, nb, url)),
            ],
            // Three slots always: one photo is not stretched across the card.
            for (var i = urls.length; i < 3; i++) ...[
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ],
    );
  }

  Widget _photo(AppLocalizations l, Notebook nb, String url) {
    final on = picked == url;
    return Semantics(
      button: true,
      selected: on,
      label: l.recipeAiDraftPhotos,
      child: GestureDetector(
        key: ValueKey('draft-photo-$url'),
        onTap: () => onPick(on ? null : url),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? nb.pandan : nb.line,
                width: on ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: 360,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: nb.line,
                    child: Icon(Icons.broken_image_outlined, color: nb.inkSoft),
                  ),
                ),
                if (on)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: nb.pandan,
                        child: Icon(Icons.check, size: 15, color: nb.paper),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pages an AI draft read, as chips: tap to open and check one.
class DraftSourceChips extends StatelessWidget {
  const DraftSourceChips({super.key, required this.sources});

  final List<({String url, String? title})> sources;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final src in sources)
          ActionChip(
            avatar: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              Uri.tryParse(src.url)?.host.replaceFirst('www.', '') ?? src.url,
            ),
            tooltip: src.title ?? src.url,
            onPressed: () => openLink(context, src.url, failed: l.openFailed),
          ),
      ],
    );
  }
}
