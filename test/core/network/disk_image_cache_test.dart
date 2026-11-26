import 'dart:io';

import 'package:bukuresipi_flutter/core/network/disk_image_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('covers');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'downloaded once, then read from disk; a bad name is never a file',
    () async {
      var fetched = 0;
      Future<Uint8List?> fetch() async {
        fetched++;
        return Uint8List.fromList([1, 2, 3]);
      }

      expect(await diskCached('cover-abc', fetch), [1, 2, 3]);
      await Future<void>.delayed(
        const Duration(milliseconds: 50),
      ); // the write runs behind
      expect(await diskCached('cover-abc', fetch), [1, 2, 3]);
      expect(fetched, 1);

      // As a path it would land at <tmp>/escaped: a file that exists only if the name check failed (on Linux,
      // <tmp>/../../etc/passwd is the real /etc/passwd, so that probe always "existed").
      expect(await diskCached('../escaped', fetch), [1, 2, 3]);
      expect(fetched, 2); // fetched, never stored as a path
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(File('${tmp.path}/escaped').existsSync(), isFalse);
    },
  );
}
