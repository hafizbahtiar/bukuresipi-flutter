import 'dart:convert';

enum Strength { weak, fair, good, strong }

/// Password rules for the strength meter. Only [length] is required (the API's rule: 8-72 bytes, not only spaces);
/// the others are advice that raise [strength].
class PasswordCheck {
  const PasswordCheck({
    required this.length,
    required this.lower,
    required this.upper,
    required this.number,
    required this.symbol,
    required this.long,
  });

  final bool length, lower, upper, number, symbol;
  final bool long; // 12+ characters

  Strength get strength {
    if (!length) return Strength.weak;
    final points = [
      lower,
      upper,
      number,
      symbol,
      long,
    ].where((ok) => ok).length;
    return switch (points) {
      <= 1 => Strength.weak,
      2 => Strength.fair,
      3 => Strength.good,
      _ => Strength.strong,
    };
  }
}

PasswordCheck checkPassword(String p) {
  final bytes = utf8.encode(p).length;
  return PasswordCheck(
    length: bytes >= 8 && bytes <= 72 && p.trim().isNotEmpty,
    lower: p.contains(RegExp(r'\p{Ll}', unicode: true)),
    upper: p.contains(RegExp(r'\p{Lu}', unicode: true)),
    number: p.contains(RegExp(r'\d')),
    symbol: p.contains(RegExp(r'[^\p{L}\p{N}]', unicode: true)),
    long: p.runes.length >= 12,
  );
}
