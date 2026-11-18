import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme, nb) in [
    ('light', AppTheme.light(), Notebook.light),
    ('dark', AppTheme.dark(), Notebook.dark),
  ]) {
    test('switches use the notebook palette, off and on ($name)', () {
      final s = theme.switchTheme;
      const off = <WidgetState>{};
      const on = {WidgetState.selected};
      expect(s.trackColor!.resolve(off), nb.mist);
      expect(s.thumbColor!.resolve(off), nb.inkSoft.withValues(alpha: 0.75));
      expect(
        s.trackOutlineColor!.resolve(off),
        nb.inkSoft.withValues(alpha: 0.35),
      );
      expect(s.trackColor!.resolve(on), nb.pandan);
      expect(s.thumbColor!.resolve(on), nb.paper);
      expect(s.trackOutlineColor!.resolve(on), Colors.transparent);
      // Disabled: the same colours, faded.
      expect(
        s.trackColor!.resolve({WidgetState.disabled})!.a,
        lessThan(nb.mist.a),
      );
    });
  }
}
