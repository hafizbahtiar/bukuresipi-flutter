import 'dart:io';

/// The image's real type from its first bytes (`jpeg`, `png`, `webp`), null = none of them or unreadable. The file name
/// can't say: image_picker saves a resized HEIC as JPEG under its `.heic` name, and an image with transparency as PNG.
Future<String?> imageSubtype(String path) async {
  final head = <int>[];
  try {
    await for (final part in File(path).openRead(0, 12)) {
      head.addAll(part);
    }
  } on FileSystemException {
    return null;
  }
  bool at(int from, List<int> bytes) =>
      head.length >= from + bytes.length &&
      [for (var i = 0; i < bytes.length; i++) head[from + i] == bytes[i]]
          .every((same) => same);
  if (at(0, const [0xff, 0xd8, 0xff])) return 'jpeg';
  if (at(0, const [0x89, 0x50, 0x4e, 0x47])) return 'png';
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'webp';
  return null;
}
