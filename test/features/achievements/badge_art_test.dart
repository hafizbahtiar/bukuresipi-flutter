import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  // A badge on an opaque square shows a white tile in dark mode (QuickLook renders did).
  test('every badge PNG has a transparent background', () async {
    final files = Directory('assets/badges')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'));
    expect(files, hasLength(30));
    for (final f in files) {
      final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(
        rgba.getUint8(3),
        0,
        reason: '${f.path}: corner pixel is not transparent',
      );
    }
  });
}
