import 'dart:convert';

import 'package:bukuresipi_flutter/core/widgets/skeleton.dart';
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

  testWidgets(
    'a card photo shimmers while loading, then the photo or the fallback',
    (t) async {
      Future<void> load(FakeShares repo, String id) async {
        await t.pumpWidget(
          Provider<ShareRepository>.value(
            value: repo,
            child: MaterialApp(
              home: SizedBox.square(
                dimension: 100,
                // A key per photo: a fresh widget, not one keeping the last photo while the next loads.
                child: ShareFill(
                  key: ValueKey(id),
                  id: id,
                  fallback: const Text('none'),
                ),
              ),
            ),
          ),
        );
        // The first frame, before the bytes arrive: loading, not "no photo".
        expect(find.byType(Skeleton), findsOneWidget);
        expect(find.text('none'), findsNothing);
        await t.pumpAndSettle();
        expect(find.byType(Skeleton), findsNothing);
      }

      await load(FakeShares()..imageBytes = _png, 'f1');
      expect(find.byType(Image), findsOneWidget);
      // A list row scrolled back into view (a new SharePhoto of a photo already shown): the photo in its first
      // frame, no shimmer.
      await _pump(
        t,
        FakeShares()..imageBytes = _png,
        child: const SharePhoto('p1'),
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        Provider<ShareRepository>.value(
          value: FakeShares()..imageBytes = _png,
          child: const MaterialApp(home: Scaffold(body: SharePhoto('p1'))),
        ),
      );
      expect(find.byType(Skeleton), findsNothing);
      expect(find.byType(Image), findsOneWidget);

      // One with no photo: rebuilt, it has its final (empty) size at once. A shimmer first, then nothing, changed
      // the height of rows above the screen, and the list jumped while scrolling up.
      await _pump(t, FakeShares(), child: const SharePhoto('p2'));
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        Provider<ShareRepository>.value(
          value: FakeShares(),
          child: const MaterialApp(home: Scaffold(body: SharePhoto('p2'))),
        ),
      );
      expect(find.byType(Skeleton), findsNothing);
      await load(FakeShares(), 'f2');
      expect(find.text('none'), findsOneWidget);
    },
  );
}
