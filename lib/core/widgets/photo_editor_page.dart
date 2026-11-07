import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart' hide ImageSource;
import 'package:image_picker/image_picker.dart';

import '../../l10n/gen/app_localizations.dart';

/// JPEG quality for every photo the app uploads (covers, profile pictures): high, the size is capped by [pickPhoto].
const photoQuality = 97;

/// Pick from the gallery (system Photo Picker: no permission), then crop/rotate/flip in [PhotoEditorPage].
/// Returns a local JPEG path, or null when the user backs out. [maxSide] caps the pixels before editing.
Future<String?> pickPhoto(
  BuildContext context, {
  required List<(String, double?)> ratios,
  double maxSide = 1600,
}) async {
  final navigator = Navigator.of(context);
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxSide,
    maxHeight: maxSide,
    imageQuality: 100, // encoded once, at photoQuality, after editing
  );
  if (picked == null) return null;
  return navigator.push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoEditorPage(path: picked.path, ratios: ratios),
    ),
  );
}

/// A simple editor: crop (the [ratios] presets, null = free), rotate, flip, reset. Pops a JPEG path.
class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({super.key, required this.path, required this.ratios});

  final String path;

  /// (label, width / height); the first is the start. null = free crop.
  final List<(String, double?)> ratios;

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  final _editor = ImageEditorController();
  late double? _ratio = widget.ratios.first.$2;
  bool _saving = false;

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final action = _editor.editActionDetails;
    final state = _editor.state;
    if (action == null || state == null) return;
    setState(() => _saving = true);
    try {
      final option = ImageEditorOption()
        ..outputFormat = const OutputFormat.jpeg(photoQuality);
      if (action.hasRotateDegrees) {
        option.addOption(RotateOption(action.rotateDegrees.toInt()));
      }
      if (action.flipY) {
        option.addOption(const FlipOption(horizontal: true, vertical: false));
      }
      if (action.needCrop) {
        option.addOption(ClipOption.fromRect(_editor.getCropRect()!));
      }
      final bytes = await ImageEditor.editImage(
        image: state.rawImageData,
        imageEditorOption: option,
      );
      if (bytes == null) throw StateError('no output');
      final out = File(
        '${Directory.systemTemp.path}/photo-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(bytes);
      navigator.pop(out.path);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.photoEditFailed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.photoEditTitle),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              key: const ValueKey('photo-done'),
              onPressed: _done,
              child: Text(l.photoUse),
            ),
        ],
      ),
      body: ExtendedImage.file(
        File(widget.path),
        fit: BoxFit.contain,
        mode: ExtendedImageMode.editor,
        cacheRawData: true, // the editor crops the original bytes
        initEditorConfigHandler: (_) => EditorConfig(
          maxScale: 4,
          cropRectPadding: const EdgeInsets.all(20),
          initCropRectType: InitCropRectType.imageRect,
          cropAspectRatio: _ratio,
          controller: _editor,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.ratios.length > 1)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (label, ratio) in widget.ratios)
                      ChoiceChip(
                        label: Text(label),
                        selected: _ratio == ratio,
                        onSelected: (_) {
                          setState(() => _ratio = ratio);
                          _editor.updateCropAspectRatio(ratio);
                        },
                      ),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (icon, label, act) in [
                    (
                      Icons.rotate_left,
                      l.photoRotate,
                      () => _editor.rotate(degree: -90),
                    ),
                    (Icons.flip, l.photoFlip, _editor.flip),
                    (Icons.restart_alt, l.photoReset, _editor.reset),
                  ])
                    IconButton(
                      tooltip: label,
                      color: Colors.white,
                      icon: Icon(icon),
                      onPressed: _saving ? null : act,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
