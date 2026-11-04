import 'package:bukuresipi_flutter/core/widgets/notebook.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_rating_bursts_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_reports_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_review_reports_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_users_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../owner_fixtures.dart';

void main() {
  late FakeOwner repo;
  setUp(() => repo = FakeOwner());

  Future<void> pump(WidgetTester t, Widget page) async {
    // A phone-sized screen: the meter list sits below the counts.
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      Provider<OwnerRepository>.value(
        value: repo,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'the overview shows the counts and each meter\'s use against its cap',
    (t) async {
      await pump(t, const OwnerPage());
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Nominatim'), findsOneWidget);
      expect(find.text('90 / 100 a month'), findsOneWidget);
    },
  );

  testWidgets(
    'reports is a notebook page with an open and closed empty state',
    (t) async {
      repo.tickets = [];
      await pump(t, const OwnerReportsPage());
      expect(find.byType(NotebookPage), findsOneWidget);
      expect(find.byType(NotebookTitle), findsOneWidget);
      expect(find.byType(NotebookSegmented<String>), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('No reports.'), findsOneWidget);
      expect(find.text('Community reports will show up here.'), findsOneWidget);
      expect(repo.reportQueries, ['open', 'closed']);

      await t.tap(find.text('Closed'));
      await t.pumpAndSettle();
      // Switching tabs uses the cached list: no spinner and no new request.
      expect(repo.reportQueries, ['open', 'closed']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No closed reports.'), findsOneWidget);
      expect(
        find.text('Applied and rejected tickets will show up here.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('review reports show the review and hide it after confirmation', (
    t,
  ) async {
    repo.reviewReportGroups = [
      ReviewReportGroup(
        reviewId: 'r-1',
        stars: 1,
        text: 'Review yang salah.',
        author: 'Aina',
        hidden: false,
        createdAt: DateTime.utc(2026, 11, 4),
        count: 2,
        reasons: const ['spam', 'offensive'],
        latestNote: 'Spam',
        updatedAt: DateTime.utc(2026, 11, 4),
      ),
    ];
    await pump(t, const OwnerReviewReportsPage());
    expect(find.text('Review yang salah.'), findsOneWidget);
    expect(find.text('Aina'), findsOneWidget);
    expect(find.text('2 reports'), findsOneWidget);

    await t.tap(find.text('Hide review'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Hide review').last);
    await t.pumpAndSettle();
    expect(repo.reviewResolved, [('r-1', true)]);
  });

  testWidgets('a meter is edited in a notebook sheet, cap and period', (
    t,
  ) async {
    await pump(t, const OwnerPage());
    await t.tap(find.text('Nominatim'));
    await t.pumpAndSettle();
    expect(find.text('Cap applies per'), findsOneWidget);
    await t.enterText(find.byType(TextField), '500');
    await t.pump();
    await t.tap(find.text('Day'));
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(repo.meterUpdates, [('geo:nominatim', 500, 'day', true)]);
    expect(find.text('90 / 500 a day'), findsOneWidget);
  });

  testWidgets('users are searched, and ending a user\'s sessions asks first', (
    t,
  ) async {
    repo.users = [
      ownerUser('siti@b.c', shares: 2),
      ownerUser('ali@b.c', verified: false),
    ];
    await pump(t, const OwnerUsersPage());
    expect(find.text('siti@b.c'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'ali');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(repo.queries.last, 'ali');
    expect(find.text('siti@b.c'), findsNothing);
    await t.tap(find.text('ali@b.c'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sign out everywhere'));
    await t.pumpAndSettle();
    expect(repo.loggedOut, isEmpty);
    await t.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await t.pumpAndSettle();
    expect(repo.loggedOut, ['u-ali@b.c']);
  });

  testWidgets(
    'rating bursts list who rated; the owner deletes one after confirming',
    (t) async {
      repo.bursts = [
        RatingBurst(
          branchId: 'b1',
          restaurant: 'Warung Uji',
          label: 'Ampang',
          newAccounts: 3,
          ratings: [
            BurstRating(
              id: 'r1',
              stars: 5,
              text: 'Terbaik',
              hidden: false,
              createdAt: DateTime.utc(2026, 11, 4),
              email: 'new1@b.c',
              joinedAt: DateTime.utc(2026, 11, 3),
              emailVerified: true,
            ),
          ],
        ),
      ];
      await pump(t, const OwnerRatingBurstsPage());
      expect(find.text('Warung Uji · Ampang'), findsOneWidget);
      expect(
        find.text('3 ratings from new accounts this week'),
        findsOneWidget,
      );
      expect(find.text('new1@b.c'), findsOneWidget);
      await t.tap(find.byTooltip('Delete rating'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete rating').last);
      await t.pumpAndSettle();
      expect(repo.deletedRatings, ['r1']);
      expect(find.text('new1@b.c'), findsNothing);
    },
  );

  testWidgets('no bursts: a calm empty state', (t) async {
    await pump(t, const OwnerRatingBurstsPage());
    expect(find.text('No unusual ratings this week.'), findsOneWidget);
  });
}
