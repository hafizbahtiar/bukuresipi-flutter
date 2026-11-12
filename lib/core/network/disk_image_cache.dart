import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart' show cacheImageFolderName;
import 'package:path_provider/path_provider.dart';

/// Private photos (avatars, recipe and restaurant covers) kept on disk across app starts. They can't be plain network
/// images: the request needs the token, which Dio refreshes. So [fetch] downloads through Dio and the bytes go into
/// extended_image's disk cache folder (its clearDiskCachedImages() empties it too). [name] is the photo's id: a new
/// picture has a new id, so a cached file is never stale.
Future<Uint8List?> diskCached(
  String name,
  Future<Uint8List?> Function() fetch,
) async {
  final file = await _file(name);
  if (file != null && await file.exists()) {
    try {
      return await file.readAsBytes();
    } catch (_) {} // unreadable: download it again
  }
  final bytes = await fetch();
  if (bytes != null && file != null) {
    unawaited(
      file
          .create(recursive: true)
          .then((f) => f.writeAsBytes(bytes))
          .then((_) {}, onError: (Object _) {}),
    );
  }
  return bytes;
}

final _safeName = RegExp(r'^[0-9A-Za-z_-]{1,100}$');

/// null = no disk (tests, web) or not a name the server could give (never a path out of the folder).
Future<File?> _file(String name) async {
  if (!_safeName.hasMatch(name)) return null;
  try {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$cacheImageFolderName/$name');
  } catch (_) {
    return null;
  }
}
