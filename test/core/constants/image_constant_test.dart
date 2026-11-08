import 'dart:io';

import 'package:bukuresipi_flutter/core/constants/image_constant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every image constant points at a file in the app', () {
    for (final path in ImageConstant.all) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
