import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/base.dart' show showBaseSheet;
import '../../../../core/theme/app_theme_constant.dart';
import '../../../shares/presentation/widgets/share_image.dart';
import '../../../../core/widgets/photo_editor_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/place.dart';
import '../places_controller.dart';

/// Owner only: pick the restaurant's cover for everyone from the thumbnails of the posts shared about it, or take
/// or pick a photo of their own.
class CoverPickerSheet extends StatefulWidget {
  const CoverPickerSheet({super.key, required this.placeId, this.selected});

  final String placeId;

  /// The choice already made on the page (not saved yet); null = the saved cover is marked.
  final CoverChoice? selected;

  @override
  State<CoverPickerSheet> createState() => _CoverPickerSheetState();
}

/// What the owner picked; nothing is saved until the page's Save. [cover] = a candidate id, [path] = a photo of
/// their own; both null = no cover.
typedef CoverChoice = ({String? cover, String? path});

class _CoverPickerSheetState extends State<CoverPickerSheet> {
  late final _candidates = context.read<PlacesController>().coverCandidates(
    widget.placeId,
  );

  /// A photo of the owner's own: camera or gallery, cropped in the photo editor.
  Future<void> _photo(ImageSource source) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final path = await pickPhoto(
      context,
      source: source,
      ratios: [('4:3', 4 / 3), ('1:1', 1), (l.photoFree, null)],
    );
    if (path != null && mounted) {
      navigator.pop<CoverChoice>((cover: null, path: path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    void pick(String? cover) =>
        Navigator.of(context).pop<CoverChoice>((cover: cover, path: null));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: FutureBuilder(
        future: _candidates,
        builder: (context, s) {
          final data = s.data;
          final marked = switch (widget.selected) {
            null => data?.current,
            final c => c.cover,
          };
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.coverTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (s.hasError)
                Text(
                  errorText(l, s.error!),
                  style: TextStyle(color: nb.inkSoft),
                )
              else if (data == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (data.covers.isEmpty)
                Text(l.coverEmpty, style: TextStyle(color: nb.inkSoft))
              else
                Flexible(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final c in data.covers)
                        _Candidate(
                          key: ValueKey('cover-$c'),
                          placeId: widget.placeId,
                          cover: c,
                          selected: c == marked,
                          onTap: () => pick(c),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('cover-camera'),
                      onPressed: () => _photo(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l.coverCamera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('cover-gallery'),
                      onPressed: () => _photo(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l.coverGallery),
                    ),
                  ),
                ],
              ),
              if (data?.current != null || widget.selected?.cover != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => pick(null),
                  child: Text(l.coverNone),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Candidate extends StatefulWidget {
  const _Candidate({
    super.key,
    required this.placeId,
    required this.cover,
    required this.selected,
    required this.onTap,
  });

  final String placeId;
  final String cover;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_Candidate> createState() => _CandidateState();
}

class _CandidateState extends State<_Candidate> {
  late final Future<Uint8List?> _bytes = context
      .read<PlacesController>()
      .coverCandidate(widget.placeId, widget.cover)
      .catchError((Object _) => null);

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Material(
      color: nb.mist,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: widget.selected ? nb.pandan : nb.line,
          width: widget.selected ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: FutureBuilder(
          future: _bytes,
          builder: (context, s) => switch (s.data) {
            final b? => Image.memory(b, fit: BoxFit.cover, cacheWidth: 300),
            null => Icon(Icons.image_outlined, color: nb.inkSoft),
          },
        ),
      ),
    );
  }
}

/// Owner, Edit place: the place's cover as everyone sees it (the cover, else the post's picture), or the [choice]
/// made in [CoverPickerSheet] as it will be after the page's Save (nothing is saved here).
class PlaceCoverField extends StatelessWidget {
  const PlaceCoverField({
    super.key,
    required this.restaurantId,
    required this.choice,
    required this.onChanged,
  });

  final String restaurantId;
  final CoverChoice? choice;
  final ValueChanged<CoverChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final place = context.select<PlacesController, Place?>(
      (c) => c.places.where((p) => p.restaurant.id == restaurantId).firstOrNull,
    );
    final cover = place?.restaurant.cover;
    final photoId = cover ?? place?.shareId;
    final empty = ColoredBox(
      color: nb.mist,
      child: Icon(Icons.image_outlined, size: 40, color: nb.inkSoft),
    );
    final c = choice;
    // What shows: the pending choice, else what is saved.
    final none = c == null
        ? photoId == null
        : c.cover == null && c.path == null;
    final change = TextButton.icon(
      key: const ValueKey('place-cover-change'),
      onPressed: () async {
        final picked = await showBaseSheet<CoverChoice>(
          context,
          builder: (_) =>
              CoverPickerSheet(placeId: restaurantId, selected: choice),
        );
        if (picked != null) onChanged(picked);
      },
      icon: const Icon(Icons.image_outlined, size: 18),
      label: Text(none ? l.coverAdd : l.coverChange),
    );
    final note = c == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: spaceXs),
            child: Text(
              l.coverAfterSave,
              key: const ValueKey('place-cover-pending'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: nb.inkSoft),
            ),
          );
    // Nothing to show: one line, not a big empty frame.
    if (none) {
      return Column(
        key: const ValueKey('place-cover-field'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              spaceM,
              spaceXs,
              spaceXs,
              spaceXs,
            ),
            decoration: BoxDecoration(
              color: nb.mist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.image_not_supported_outlined, color: nb.inkSoft),
                const SizedBox(width: spaceS),
                Expanded(child: Text(l.coverNoneYet)),
                change,
              ],
            ),
          ),
          ?note,
        ],
      );
    }
    return Column(
      key: const ValueKey('place-cover-field'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: switch ((c, photoId)) {
              ((cover: _, path: final path?), _) => Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => empty,
              ),
              ((cover: final id?, path: _), _) => _Candidate(
                key: ValueKey('place-cover-pick-$id'),
                placeId: restaurantId,
                cover: id,
                selected: false,
                onTap: null,
              ),
              (null, final id?) => ShareFill(
                id: id,
                placeId: cover == null ? null : restaurantId,
                fallbackShareId: cover == null ? null : place?.shareId,
                fallback: empty,
                cacheWidth: 1000,
              ),
              _ => empty,
            },
          ),
        ),
        ?note,
        Align(alignment: Alignment.centerLeft, child: change),
      ],
    );
  }
}

/// A branch's own cover photo, filling its box; [fallback] while loading or when it won't load.
class BranchPhoto extends StatefulWidget {
  const BranchPhoto({
    super.key,
    required this.branchId,
    required this.cover,
    required this.fallback,
  });

  final String branchId;
  final String cover;
  final Widget fallback;

  @override
  State<BranchPhoto> createState() => _BranchPhotoState();
}

class _BranchPhotoState extends State<BranchPhoto> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() => context
      .read<PlacesController>()
      .branchCover(widget.branchId, widget.cover)
      .catchError((Object _) => null);

  @override
  void didUpdateWidget(BranchPhoto old) {
    super.didUpdateWidget(old);
    if (old.cover != widget.cover || old.branchId != widget.branchId) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (_, s) => s.data == null
        ? widget.fallback
        : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true),
  );
}

/// Owner, Edit branch: this outlet's own photo (its shop front), or the AI draft's photo [picked] as it will be after
/// Save; take one, pick one from the gallery, or remove it (each saved at once). Edit place can take it as the cover.
class BranchCoverField extends StatefulWidget {
  const BranchCoverField({super.key, required this.branchId, this.picked});

  final String branchId;
  final String? picked;

  @override
  State<BranchCoverField> createState() => _BranchCoverFieldState();
}

class _BranchCoverFieldState extends State<BranchCoverField> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(PlacesController) work) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    setState(() => _busy = true);
    try {
      await work(places);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(ImageSource source) async {
    final l = AppLocalizations.of(context);
    final path = await pickPhoto(
      context,
      source: source,
      ratios: [('4:3', 4 / 3), ('1:1', 1), (l.photoFree, null)],
    );
    if (path == null || !mounted) return;
    await _run((places) => places.uploadBranchCover(widget.branchId, path));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final soft = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: nb.inkSoft);
    // The book's copy: a new photo shows as soon as it is saved.
    final cover = context.select<PlacesController, String?>(
      (c) => c.places
          .expand((p) => p.branches)
          .where((b) => b.id == widget.branchId)
          .firstOrNull
          ?.cover,
    );
    final empty = ColoredBox(
      color: nb.mist,
      child: Icon(Icons.storefront_outlined, size: 40, color: nb.inkSoft),
    );
    final picked = widget.picked;
    return Column(
      key: const ValueKey('branch-cover-field'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.branchCoverTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: spaceXs),
        if (picked != null || cover != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: picked != null
                  ? Image.network(
                      picked,
                      key: const ValueKey('branch-cover-draft'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => empty,
                    )
                  : BranchPhoto(
                      branchId: widget.branchId,
                      cover: cover!,
                      fallback: empty,
                    ),
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        Text(
          picked != null ? l.coverAfterSave : l.branchCoverNote,
          style: soft,
        ),
        Wrap(
          spacing: spaceS,
          children: [
            TextButton.icon(
              key: const ValueKey('branch-cover-camera'),
              onPressed: _busy ? null : () => _upload(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(l.coverCamera),
            ),
            TextButton.icon(
              key: const ValueKey('branch-cover-gallery'),
              onPressed: _busy ? null : () => _upload(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(l.coverGallery),
            ),
            if (cover != null)
              TextButton.icon(
                key: const ValueKey('branch-cover-remove'),
                onPressed: _busy
                    ? null
                    : () => _run(
                        (places) =>
                            places.setBranchCover(widget.branchId, null),
                      ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l.recipeCoverRemove),
              ),
          ],
        ),
      ],
    );
  }
}
