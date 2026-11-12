import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/photo_editor_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../places_controller.dart';

/// Owner only: pick the restaurant's cover for everyone from the thumbnails of the posts shared about it, or take
/// or pick a photo of their own.
class CoverPickerSheet extends StatefulWidget {
  const CoverPickerSheet({super.key, required this.placeId});

  final String placeId;

  @override
  State<CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends State<CoverPickerSheet> {
  late final _candidates = context.read<PlacesController>().coverCandidates(
    widget.placeId,
  );
  bool _saving = false;

  Future<void> _pick(String? cover) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await context.read<PlacesController>().setRestaurantCover(
        widget.placeId,
        cover,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.coverSaved)));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A photo of the owner's own: camera or gallery, cropped in the photo editor, then uploaded.
  Future<void> _upload(ImageSource source) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final places = context.read<PlacesController>();
    final path = await pickPhoto(
      context,
      source: source,
      ratios: [('4:3', 4 / 3), ('1:1', 1), (l.photoFree, null)],
    );
    if (path == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await places.uploadRestaurantCover(widget.placeId, path);
      messenger.showSnackBar(SnackBar(content: Text(l.coverSaved)));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FutureBuilder(
          future: _candidates,
          builder: (context, s) {
            final data = s.data;
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
                            selected: c == data.current,
                            onTap: _saving ? null : () => _pick(c),
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
                        onPressed: _saving
                            ? null
                            : () => _upload(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l.coverCamera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('cover-gallery'),
                        onPressed: _saving
                            ? null
                            : () => _upload(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l.coverGallery),
                      ),
                    ),
                  ],
                ),
                if (data?.current != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _pick(null),
                    child: Text(l.coverNone),
                  ),
                ],
              ],
            );
          },
        ),
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
