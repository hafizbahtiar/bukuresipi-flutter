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

Future<void> _pump(WidgetTester t, FakeShares repo) async {
  await t.pumpWidget(
    Provider<ShareRepository>.value(
      value: repo,
      child: const MaterialApp(home: Scaffold(body: ShareImage('s1'))),
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
}
