import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// `flutter test --dart-define=TEST_SIZE=1280x800` runs every test at that screen size: a tablet or landscape check.
// Look for "overflowed" in the output; a test that cannot find a row on a short screen is not a layout bug.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const size = String.fromEnvironment('TEST_SIZE');
  if (size.isNotEmpty) {
    final [w, h] = size.split('x').map(double.parse).toList();
    setUp(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!;
      view.physicalSize = Size(w, h);
      view.devicePixelRatio = 1;
    });
  }
  await testMain();
}
