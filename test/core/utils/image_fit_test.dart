import 'package:bukuresipi_flutter/core/utils/image_fit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a shared image shrinks to 2000 x 4000 at most, keeping its shape; never enlarged', () {
    expect(fitScale(1080, 2400), 1); // a phone screenshot fits
    expect(fitScale(4000, 3000), 0.5); // a camera photo: by width
    expect(
      fitScale(1080, 12000),
      closeTo(1 / 3, 1e-9),
    ); // a long scroll capture: by height
  });
}
