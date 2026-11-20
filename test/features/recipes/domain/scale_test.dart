import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amounts scale as a cook writes them; words stay', () {
    expect(scaleQuantity('2', 1.5), '3');
    expect(scaleQuantity('1/2', 3), '1½');
    expect(scaleQuantity('1 1/2', 0.5), '¾');
    expect(scaleQuantity('1½', 2), '3');
    expect(scaleQuantity('3-4', 2), '6-8');
    expect(scaleQuantity('500', 1.5), '750');
    expect(scaleQuantity('1,5', 2), '3');
    expect(scaleQuantity('1', 1 / 3), '0.3');
    expect(scaleQuantity('secukupnya', 2), 'secukupnya');
    expect(scaleQuantity('segenggam kecil', 2), 'segenggam kecil');
    expect(scaleQuantity(null, 2), isNull);
    expect(scaleQuantity('2', 1), '2');
  });
}
