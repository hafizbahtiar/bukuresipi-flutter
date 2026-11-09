import 'dart:convert';

import 'package:bukuresipi_flutter/features/shares/domain/share_repository.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/widgets/share_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'share_intake_test.dart' show FakeShares;

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<void> _pump(
  WidgetTester t,
  FakeShares repo, {
  Widget child = const ShareImage('s1'),
}) async {
  await t.pumpWidget(
    Provider<ShareRepository>.value(
      value: repo,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows the image when the share has one', (t) async {
    await _pump(t, FakeShares()..imageBytes = _png);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('takes no space when there is none', (t) async {
    await _pump(t, FakeShares());
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'the taped photo in a list row: shown when there is one, nothing otherwise',
    (t) async {
      await _pump(
        t,
        FakeShares()..imageBytes = _png,
        child: const SharePhoto('s1'),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(t.getSize(find.byType(Image)), const Size(52, 52));

      await _pump(t, FakeShares(), child: const SharePhoto('s2'));
      expect(find.byType(Image), findsNothing);
    },
  );
}
