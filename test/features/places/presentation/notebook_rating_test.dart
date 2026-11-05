import 'dart:async';

import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/notebook_rating.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('ms')],
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows the average/count and rates or clears a star', (t) async {
    final calls = <int?>[];
    await t.pumpWidget(
      app(
        NotebookRating(
          rating: const RatingSummary(
            average: 4.3,
            count: 7,
            mine: 4,
            canRate: true,
          ),
          onRate: (stars) async {
            calls.add(stars);
            return RatingSummary(
              average: 4.3,
              count: 7,
              mine: stars,
              canRate: true,
            );
          },
        ),
      ),
    );

    expect(find.text('4.3 · 7 ratings'), findsOneWidget);
    expect(find.text('Your rating: 4'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('rating-star-5')));
    await t.pump();
    // The stars change at once; the request goes after a short pause.
    expect(find.text('Your rating: 5'), findsOneWidget);
    expect(calls, isEmpty);
    await t.pump(const Duration(milliseconds: 500));
    expect(calls, [5]);

    await t.tap(find.byKey(const ValueKey('rating-star-5')));
    await t.pump(const Duration(milliseconds: 500));
    expect(calls, [5, null]);
  });

  testWidgets('hides the average below three ratings and is read-only', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        const NotebookRating(
          rating: RatingSummary(count: 2, mine: 2),
          hint: 'Save this place to rate it.',
        ),
      ),
    );
    expect(find.text('2 ratings · Not enough ratings yet.'), findsOneWidget);
    expect(find.text('Save this place to rate it.'), findsOneWidget);
    expect(find.byKey(const ValueKey('rating-star-5')), findsNothing);
  });

  testWidgets('empty rating has a clear empty state', (t) async {
    await t.pumpWidget(app(const NotebookRating(rating: RatingSummary())));
    expect(find.text('No ratings yet.'), findsOneWidget);
  });

  testWidgets('narrow space and large text: stars shrink, nothing overflows', (
    t,
  ) async {
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: app(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 150,
              child: NotebookRating(
                rating: const RatingSummary(
                  average: 4.3,
                  count: 7,
                  canRate: true,
                ),
                onRate: (_) async => const RatingSummary(),
              ),
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('rating-star-5')), findsOneWidget);
  });

  testWidgets('the one-line summary wraps on a narrow row and opens reviews', (
    t,
  ) async {
    var opened = 0;
    await t.pumpWidget(
      app(
        SizedBox(
          width: 120,
          child: RatingLine(
            rating: const RatingSummary(average: 4.3, count: 7, reviewCount: 2),
            onTap: () => opened++,
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    await t.tap(find.byType(RatingLine));
    expect(opened, 1);
  });

  testWidgets('sliding a finger along the stars rates on lift', (t) async {
    final calls = <int?>[];
    await t.pumpWidget(
      app(
        NotebookRating(
          rating: const RatingSummary(canRate: true),
          onRate: (stars) async {
            calls.add(stars);
            return RatingSummary(mine: stars, canRate: true, count: 1);
          },
        ),
      ),
    );
    final gesture = await t.startGesture(
      t.getCenter(find.byKey(const ValueKey('rating-star-1'))),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(90, 0)); // over star 4
    await t.pump(const Duration(milliseconds: 100));
    expect(calls, isEmpty); // nothing saved while the finger is down
    await gesture.up();
    await t.pump(const Duration(milliseconds: 500));
    expect(calls, [4]);
    expect(find.text('Your rating: 4'), findsOneWidget);
  });

  testWidgets(
    'tapping stars quickly sends one request, never a spinner; a tap during a request is sent after it',
    (t) async {
      final calls = <int?>[];
      Completer<void>? slow;
      await t.pumpWidget(
        app(
          NotebookRating(
            rating: const RatingSummary(canRate: true),
            onRate: (stars) async {
              calls.add(stars);
              await slow?.future;
              return RatingSummary(mine: stars, canRate: true, count: 1);
            },
          ),
        ),
      );
      for (final n in [1, 2, 3, 4, 5]) {
        await t.tap(find.byKey(ValueKey('rating-star-$n')));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.pump(const Duration(milliseconds: 500));
      expect(calls, [5]);

      slow = Completer();
      await t.tap(find.byKey(const ValueKey('rating-star-2')));
      await t.pump(
        const Duration(milliseconds: 500),
      ); // request for 2 starts, hangs
      await t.tap(find.byKey(const ValueKey('rating-star-3')));
      await t.pump(const Duration(milliseconds: 500)); // 3 waits for it
      expect(calls, [5, 2]);
      expect(find.text('Your rating: 3'), findsOneWidget);
      slow.complete();
      await t.pump();
      await t.pump();
      expect(calls, [5, 2, 3]);
      expect(find.text('Your rating: 3'), findsOneWidget);
    },
  );

  testWidgets('a failed save puts the stars back to what the server has', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        NotebookRating(
          rating: const RatingSummary(mine: 2, canRate: true, count: 1),
          onRate: (_) async => throw Exception('offline'),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('rating-star-5')));
    await t.pump();
    expect(find.text('Your rating: 5'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump();
    expect(find.text('Your rating: 2'), findsOneWidget);
  });
}
