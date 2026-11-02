import 'package:bukuresipi_flutter/features/auth/presentation/password_strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each rule is checked on its own', () {
    final c = checkPassword('abcDEF1!');
    expect(
      [c.length, c.lower, c.upper, c.number, c.symbol],
      [true, true, true, true, true],
    );
    final d = checkPassword('abc');
    expect(
      [d.length, d.lower, d.upper, d.number, d.symbol],
      [false, true, false, false, false],
    );
  });

  test(
    'a space counts as a symbol (passphrases)',
    () => expect(checkPassword('two words').symbol, isTrue),
  );

  test('strength levels', () {
    expect(checkPassword('').strength, Strength.weak);
    expect(
      checkPassword('Ab1!').strength,
      Strength.weak,
      reason: 'too short is always weak',
    );
    expect(checkPassword('password').strength, Strength.weak);
    expect(checkPassword('password1').strength, Strength.fair);
    expect(checkPassword('Password1').strength, Strength.good);
    expect(checkPassword('Password1!').strength, Strength.strong);
    expect(
      checkPassword('correct horse battery').strength,
      Strength.good,
      reason: 'long passphrase',
    );
  });

  test('length counts bytes like the API: 72 bytes max', () {
    expect(checkPassword('a' * 72).length, isTrue);
    expect(checkPassword('a' * 73).length, isFalse);
    expect(
      checkPassword('é' * 37).length,
      isFalse,
      reason: '74 bytes in UTF-8',
    );
  });
}
