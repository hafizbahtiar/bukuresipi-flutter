import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:image_editor/image_editor.dart';

/// The sides an uploaded screenshot keeps at most, as `pickScreenshot`: tall on purpose, a long capture keeps its text.
const fitWidth = 2000, fitHeight = 4000;

/// How much a [width] x [height] image shrinks to fit; 1 = it already fits (never enlarged).
double fitScale(int width, int height) =>
    [1.0, fitWidth / width, fitHeight / height].reduce(min);

/// [path] as is when it fits and is at most [maxBytes]; else a JPEG copy shrunk to fit (re-encoded even when only
/// the bytes are too many). Any failure = [path]: the size check after it still refuses what is too big.
Future<String> fitImage(String path, {required int maxBytes}) async {
  try {
    final file = File(path);
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final image = await ui.ImageDescriptor.encoded(buffer);
    final (w, h) = (image.width, image.height);
    image.dispose();
    buffer.dispose();
    final s = fitScale(w, h);
    if (s == 1 && await file.length() <= maxBytes) return path;
    final option = ImageEditorOption()
      ..outputFormat = const OutputFormat.jpeg(88)
      ..addOption(
        // keepRatio: the size above ignores a photo's rotation flag; if the plugin turns it first, never stretch.
        ScaleOption(
          max(1, (w * s).round()),
          max(1, (h * s).round()),
          keepRatio: true,
        ),
      );
    final out = await ImageEditor.editFileImageAndGetFile(
      file: file,
      imageEditorOption: option,
    );
    return out?.path ?? path;
  } catch (_) {
    return path;
  }
}
