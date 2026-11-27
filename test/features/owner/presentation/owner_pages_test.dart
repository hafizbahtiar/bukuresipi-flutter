import 'dart:async';

import 'package:bukuresipi_flutter/core/widgets/notebook.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_ai_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_catalogue_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_hidden_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_ingredients_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_rating_bursts_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_reports_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_testers_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_review_reports_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_users_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:bukuresipi_flutter/core/widgets/ai_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/owner_panel.dart';
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
          // The app theme's full-width filled button (AppTheme cannot load its fonts in tests).
          theme: ThemeData(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
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

  group('hidden content', () {
    final at = DateTime.utc(2026, 11, 20);

    testWidgets('lists both kinds; Show again asks, then removes the row', (
      t,
    ) async {
      repo.hiddenList = [
        HiddenRecipe(
          id: 'r1',
          name: 'Rendang',
          owner: 'Aina',
          public: false,
          hiddenAt: at,
        ),
      ];
      repo.hiddenReviews = [
        HiddenReview(
          id: 'v1',
          stars: 4,
          author: 'Ben',
          place: 'Warung Uji',
          hiddenAt: at,
        ),
      ];
      await pump(t, const OwnerHiddenPage());
      expect(find.text('Rendang'), findsOneWidget);
      expect(find.text('Not public now'), findsOneWidget);
      expect(find.text('The author removed this text.'), findsOneWidget);

      await t.tap(find.text('Show again').first);
      await t.pumpAndSettle();
      expect(repo.unhidden, isEmpty); // asked first
      await t.tap(find.text('Show again').last);
      await t.pumpAndSettle();
      expect(repo.unhidden, ['r1']);
      expect(find.text('Rendang'), findsNothing);
      expect(find.text('Ben'), findsOneWidget);
    });

    testWidgets('a failed call keeps the row and can be tried again', (
      t,
    ) async {
      repo.hiddenList = [
        HiddenRecipe(id: 'r1', name: 'Rendang', public: true, hiddenAt: at),
      ];
      repo.unhideError = Exception('offline');
      await pump(t, const OwnerHiddenPage());
      await t.tap(find.text('Show again'));
      await t.pumpAndSettle();
      await t.tap(find.text('Show again').last);
      await t.pumpAndSettle();
      expect(find.text('Rendang'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Show again'), findsOneWidget);
    });

    testWidgets('says when nothing is hidden', (t) async {
      await pump(t, const OwnerHiddenPage());
      expect(find.text('Nothing is hidden.'), findsOneWidget);
    });
  });

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

  testWidgets(
    'a closed-place ticket shows now and suggested in words, with the note',
    (t) async {
      repo.tickets = [
        ReportTicket(
          targetType: 'branch',
          targetId: 'b-1',
          targetName: 'Kedai A',
          targetLabel: 'Kedai A KL',
          field: 'status',
          count: 3,
          threshold: 100,
          status: 'open',
          ready: false,
          updatedAt: DateTime(2026, 11, 10),
          current: const ReportValue(value: 'open'),
          proposed: const ReportValue(value: 'closed'),
          latestNote: 'Shop is empty now',
        ),
      ];
      await pump(t, const OwnerReportsPage());
      expect(find.text('Open or closed'), findsOneWidget);
      expect(find.text('Permanently closed'), findsOneWidget);
      expect(find.text('“Shop is empty now”'), findsOneWidget);
      expect(find.text('closed'), findsNothing);
      expect(
        t.takeException(),
        isNull,
      ); // nothing overflows on a phone-sized screen
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
    await t.ensureVisible(find.text('Nominatim')); // below the owner's rows
    await t.pumpAndSettle();
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

  testWidgets('the owner bans a user for 30 days with a reason', (t) async {
    repo.users = [ownerUser('ali@b.c')];
    await pump(t, const OwnerUsersPage());
    await t.tap(find.text('ali@b.c'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('user-ban')));
    await t.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('ban-confirm'));
    // A reason first: Ban stays off until there is one.
    expect(t.widget<FilledButton>(confirm).onPressed, isNull);
    await t.enterText(
      find.byKey(const ValueKey('action-reason')),
      'Spam reviews',
    );
    await t.tap(find.byKey(const ValueKey('ban-days-30')));
    await t.pump();
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(repo.bans, [('u-ali@b.c', 30, 'Spam reviews')]);
    expect(find.text('Banned'), findsOneWidget);
  });

  testWidgets('a ban whose email failed says so', (t) async {
    repo
      ..users = [ownerUser('ali@b.c')]
      ..banEmailed = false;
    await pump(t, const OwnerUsersPage());
    await t.tap(find.text('ali@b.c'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('user-ban')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('action-reason')), 'Spam');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('ban-confirm')));
    await t.pumpAndSettle();
    expect(
      find.text('Banned. The email to the user was not sent.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a banned user shows it and can be unbanned; the owner row has no ban or delete',
    (t) async {
      repo.users = [
        ownerUser('ali@b.c', ban: (until: null, reason: 'Fake')),
        ownerUser('me@b.c', role: 'owner'),
      ];
      await pump(t, const OwnerUsersPage());
      expect(find.textContaining('Banned for good'), findsOneWidget);
      await t.tap(find.text('ali@b.c'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('user-ban')), findsNothing);
      await t.tap(find.byKey(const ValueKey('user-unban')));
      await t.pumpAndSettle();
      expect(repo.unbans, ['u-ali@b.c']);
      await t.tap(find.text('me@b.c'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('user-ban')), findsNothing);
      expect(find.byKey(const ValueKey('user-delete')), findsNothing);
    },
  );

  testWidgets(
    'deleting a user needs a reason; blocking the email is on by default',
    (t) async {
      repo.users = [ownerUser('ali@b.c')];
      await pump(t, const OwnerUsersPage());
      await t.tap(find.text('ali@b.c'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('user-delete')));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Their recipes, places, receipts, photos and reviews are deleted. This cannot be undone.',
        ),
        findsOneWidget,
      );
      await t.enterText(find.byKey(const ValueKey('action-reason')), 'Abuse');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('delete-confirm')));
      await t.pumpAndSettle();
      expect(repo.deleted, [('u-ali@b.c', 'Abuse', true)]);
    },
  );

  testWidgets(
    'bulk delete: long-press, tap to pick, the owner account never; one preset reason for all',
    (t) async {
      repo.users = [
        ownerUser('a@b.c'),
        ownerUser('b@b.c'),
        ownerUser('c@b.c'),
        ownerUser('me@b.c', role: 'owner'),
      ];
      await pump(t, const OwnerUsersPage());
      // A long-press starts picking, with that user picked.
      await t.longPress(find.text('a@b.c'));
      await t.pumpAndSettle();
      expect(find.text('1 picked'), findsOneWidget);
      await t.tap(find.text('b@b.c'));
      await t.tap(find.text('me@b.c')); // the owner: not picked, no sheet
      await t.pumpAndSettle();
      expect(find.text('2 picked'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pick-delete')));
      await t.pumpAndSettle();
      expect(find.text('Delete 2 accounts'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('delete-reason-1')));
      await t.pump();
      repo.deleteGate = Completer();
      await t.tap(find.byKey(const ValueKey('delete-confirm')));
      await t.pump(
        const Duration(seconds: 1),
      ); // the sheet closes, the first delete waits
      expect(find.text('Deleting 0 of 2…'), findsOneWidget);
      repo.deleteGate!.complete();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('deleting')), findsNothing);
      expect(repo.deleted, [
        ('u-a@b.c', 'Test account (Google Play)', true),
        ('u-b@b.c', 'Test account (Google Play)', true),
      ]);
      expect(find.text('2 accounts deleted'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget); // picking ended
    },
  );

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

  testWidgets(
    'testers: listed oldest first; copy all puts one email per line',
    (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      repo.testerList = [
        Tester(
          email: 'ali@gmail.com',
          lang: 'ms',
          joinedAt: DateTime.utc(2026, 11, 4),
        ),
        Tester(
          email: 'siti@gmail.com',
          lang: 'en',
          joinedAt: DateTime.utc(2026, 11, 5),
        ),
      ];
      await pump(t, const OwnerTestersPage());
      expect(find.text('ali@gmail.com'), findsOneWidget);
      await t.tap(find.byTooltip('Copy all emails'));
      await t.pumpAndSettle();
      expect(copied, 'ali@gmail.com\nsiti@gmail.com');
      expect(find.textContaining('2 emails copied'), findsOneWidget);
    },
  );

  testWidgets('no testers: an empty state and no copy button', (t) async {
    await pump(t, const OwnerTestersPage());
    expect(find.text('No tester signups yet.'), findsOneWidget);
    expect(find.byTooltip('Copy all emails'), findsNothing);
  });

  testWidgets(
    'testers: Done (after confirming) emails the invite; an invited row shows where the email got to',
    (t) async {
      repo.testerList = [
        Tester(
          email: 'ali@gmail.com',
          lang: 'ms',
          joinedAt: DateTime.utc(2026, 11, 4),
        ),
        Tester(
          email: 'siti@gmail.com',
          lang: 'en',
          joinedAt: DateTime.utc(2026, 11, 5),
          invitedAt: DateTime.utc(2026, 11, 6),
          emailStatus: 'bounced',
        ),
      ];
      await pump(t, const OwnerTestersPage());
      expect(find.text('Bounced'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget); // only the row not invited yet
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Add this email to the Play Console'),
        findsOneWidget,
      );
      await t.tap(find.text('Done').last);
      await t.pumpAndSettle();
      expect(repo.invited, ['ali@gmail.com']);
      expect(find.text('Invite sent.'), findsOneWidget);
    },
  );

  group('ingredient gaps', () {
    const minyak = IngredientGap(
      key: 'minyak',
      sample: 'sedikit minyak untuk menggoreng',
      recipeLines: 2,
      shoppingLines: 1,
    );

    testWidgets('the pick step scrolls on a short screen (keyboard up)', (
      t,
    ) async {
      repo.gaps = [minyak];
      repo.catalogue = [for (var i = 1; i <= 6; i++) 'Minyak $i'];
      await pump(t, const OwnerIngredientsPage());
      t.view.physicalSize = const Size(1080, 1300); // ~500 dp tall at 2.6
      await t.tap(find.byKey(const ValueKey('gap-minyak')));
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('gap-new')),
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('pick')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.byKey(const ValueKey('gap-new')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets(
      'a gap: pick the ingredient, see what the name links, save; taken names are said',
      (t) async {
        repo.gaps = [minyak];
        await pump(t, const OwnerIngredientsPage());
        expect(
          find.text(
            'Recipes 2 · Shopping lists 1\nsedikit minyak untuk menggoreng',
          ),
          findsOneWidget,
        );
        await t.tap(find.byKey(const ValueKey('gap-minyak')));
        await t.pumpAndSettle(const Duration(milliseconds: 300));
        await t.tap(find.byKey(const ValueKey('gap-ingredient-Minyak masak')));
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        expect(find.text('Links 3 lines'), findsOneWidget);

        await t.enterText(find.byKey(const ValueKey('gap-alias')), 'garam');
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        expect(
          find.text('That name is already an ingredient or another name.'),
          findsOneWidget,
        );
        expect(
          t
              .widget<BusyButton>(find.byKey(const ValueKey('gap-save')))
              .onPressed,
          isNull,
        );

        await t.enterText(find.byKey(const ValueKey('gap-alias')), 'minyak');
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        await t.tap(find.byKey(const ValueKey('gap-save')));
        await t.pumpAndSettle();
        expect(repo.aliases, [('Minyak masak', 'minyak')]);
        expect(find.text('Saved. 3 lines linked.'), findsOneWidget);
        expect(find.text('Every line has an ingredient.'), findsOneWidget);
      },
    );

    testWidgets(
      'Suggest with AI: the catalogue match opens its alias step; a name it lacks opens the new ingredient',
      (t) async {
        repo.gaps = [minyak];
        await pump(t, const OwnerIngredientsPage());
        await t.tap(find.byKey(const ValueKey('gap-minyak')));
        await t.pumpAndSettle(const Duration(milliseconds: 300));
        await t.tap(find.byKey(const ValueKey('gap-ai')));
        await t.pumpAndSettle();
        await t.tap(find.text('Same as Minyak masak'));
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        expect(find.text('Links 3 lines'), findsOneWidget);
        expect(repo.aliases, isEmpty); // nothing saved by the AI

        Navigator.of(t.element(find.text('Links 3 lines'))).pop();
        await t.pumpAndSettle();
        repo.gapAnswer = (
          name: 'daun salam',
          ingredient: null,
          category: 'Rempah',
        );
        await t.tap(find.byKey(const ValueKey('gap-minyak')));
        await t.pumpAndSettle(const Duration(milliseconds: 300));
        await t.tap(find.byKey(const ValueKey('gap-ai')));
        await t.pumpAndSettle();
        await t.tap(find.text('New ingredient: daun salam'));
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        expect(find.widgetWithText(TextField, 'Daun salam'), findsOneWidget);
        // Its category from the AI, one of ours: ready to save.
        expect(find.text('Rempah'), findsOneWidget);
        expect(
          t
              .widget<BusyButton>(find.byKey(const ValueKey('gap-save')))
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'Suggest aliases with AI: none ticked, the one that links lines first; tick and save',
      (t) async {
        repo.gaps = [minyak];
        await pump(t, const OwnerIngredientsPage());
        await t.tap(find.byKey(const ValueKey('gaps-more')));
        await t.pumpAndSettle();
        await t.tap(find.text('Suggest aliases with AI'));
        await t.pumpAndSettle();
        expect(find.text('Links 12 lines now'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(
          t.getTopLeft(find.byKey(const ValueKey('alias-ai-garlic'))).dy,
          lessThan(
            t.getTopLeft(find.byKey(const ValueKey('alias-ai-garlics'))).dy,
          ),
        );
        await t.tap(find.byKey(const ValueKey('alias-ai-all')));
        await t.pump();
        expect(find.text('Save 2'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('alias-ai-garlics')));
        await t.pump();
        expect(find.text('Save 1'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('alias-ai-save')));
        await t.pumpAndSettle();
        expect(repo.aliases, [('Bawang putih', 'garlic')]);
        expect(repo.aliasBatches, 1);
        expect(find.text('1 alias saved, 3 lines linked'), findsOneWidget);
      },
    );

    testWidgets('a new ingredient: name and category, then saved', (t) async {
      repo.gaps = [
        const IngredientGap(
          key: 'daun salam',
          sample: '2 lembar daun salam',
          recipeLines: 1,
          shoppingLines: 0,
        ),
      ];
      await pump(t, const OwnerIngredientsPage());
      await t.tap(find.byKey(const ValueKey('gap-daun salam')));
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('gap-new')));
      await t.pumpAndSettle();
      expect(find.text('Daun salam'), findsOneWidget); // the name, capitalised
      await t.tap(find.text('Category'));
      await t.pumpAndSettle();
      await t.tap(find.text('Rempah'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('gap-save')));
      await t.pumpAndSettle();
      expect(repo.newIngredients, [('Daun salam', 'Rempah')]);
    });

    testWidgets('the menu relinks every line and shows the rows for docs', (
      t,
    ) async {
      repo.gaps = [minyak];
      await pump(t, const OwnerIngredientsPage());
      await t.tap(find.byKey(const ValueKey('gaps-more')));
      await t.pumpAndSettle();
      await t.tap(find.text('Relink all lines'));
      await t.pumpAndSettle();
      expect(repo.relinks, 1);
      expect(find.text('2 of 5 lines linked.'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('gaps-more')));
      await t.pumpAndSettle();
      await t.tap(find.text('Copy rows for docs'));
      await t.pumpAndSettle();
      expect(find.text('ingredient.md'), findsOneWidget);
      expect(find.text('ingredient_alias.md'), findsNothing); // none added
      expect(
        find.text('| 289 | Daun salam | Rempah | — | — | — |'),
        findsOneWidget,
      );
    });
  });

  group('catalogue', () {
    testWidgets(
      'products, brands and makers each list, with what they link to',
      (t) async {
        await pump(t, const OwnerCataloguePage());
        expect(find.text('Beras Faiza 5kg'), findsOneWidget);
        expect(find.text('Faiza · Beras putih · 5 kg'), findsOneWidget);
        await t.tap(find.text('Brands'));
        await t.pumpAndSettle();
        expect(
          find.text('Faiza Marketing · Malaysia · 3 products'),
          findsOneWidget,
        );
        await t.tap(find.text('Makers'));
        await t.pumpAndSettle();
        expect(find.text('1 brands'), findsOneWidget);
        await t.enterText(
          find.byKey(const ValueKey('catalogue-search')),
          'faiza',
        );
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        expect(repo.catalogueQueries.last, ('makers', 'faiza'));
      },
    );

    testWidgets(
      'a brand is edited: its maker kept by id; a taken maker name is said',
      (t) async {
        await pump(t, const OwnerCataloguePage());
        await t.tap(find.text('Brands'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('catalogue-row-Faiza')));
        await t.pumpAndSettle();
        await t.tap(find.text('Country'));
        await t.pumpAndSettle();
        await t.tap(find.text('Thailand'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('catalogue-save')));
        await t.pumpAndSettle();
        expect(repo.savedRows.single.$1, 'brands');
        expect(repo.savedRows.single.$2, 1);
        expect(repo.savedRows.single.$3, {
          'name': 'Faiza',
          'makerId': 1,
          'country': 'Thailand',
        });
        expect(find.text('Saved'), findsOneWidget);
        await t.pump(const Duration(seconds: 5)); // the snackbar leaves
        await t.pumpAndSettle();

        await t.tap(find.text('Makers'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('catalogue-add')));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('catalogue-name')),
          'Taken',
        );
        await t.pump();
        await t.tap(find.byKey(const ValueKey('catalogue-save')));
        await t.pumpAndSettle();
        expect(find.text('That name is already used.'), findsOneWidget);
      },
    );

    testWidgets(
      'a new product filled from a store link: checked, its new brand added, then saved',
      (t) async {
        await pump(t, const OwnerCataloguePage());
        await t.tap(find.byKey(const ValueKey('catalogue-add')));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('catalogue-fill')),
          'https://www.jayagrocer.com/products/kara-uht-coconut-cream-200ml',
        );
        await t.tap(find.byKey(const ValueKey('catalogue-fill-go')));
        await t.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, 'Kara UHT Coconut Cream 200ml'),
          findsOneWidget,
        );
        expect(
          find.text('From www.jayagrocer.com. Check it, then save.'),
          findsOneWidget,
        );
        expect(find.byType(AiBadge), findsOneWidget); // on the ingredient
        expect(repo.savedRows, isEmpty); // nothing saved by the fill

        expect(
          find.text(
            'Made by PT Kara Santan Pertama, Indonesia (from kara.test)',
          ),
          findsOneWidget,
        );
        expect(
          find.text('New brand: Kara. Added when you save.'),
          findsOneWidget,
        );
        // One Save: the maker, the brand, then the product.
        await t.tap(find.byKey(const ValueKey('catalogue-save')));
        await t.pumpAndSettle();
        expect(repo.savedRows.map((r) => r.$1), [
          'makers',
          'brands',
          'products',
        ]);
        expect(repo.savedRows[1].$3, {
          'name': 'Kara',
          'makerId': 801,
          'country': 'Indonesia',
        });
        expect(repo.savedRows.last.$3, {
          'name': 'Kara UHT Coconut Cream 200ml',
          'ingredient': 'Santan',
          'brandId': 901,
          'size': 200.0,
          'unit': 'ml',
        });
        await t.pump(const Duration(seconds: 5)); // "Saved" leaves
        await t.pumpAndSettle();

        await t.tap(find.byKey(const ValueKey('catalogue-add')));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('catalogue-fill')),
          '0000000000000',
        );
        await t.tap(find.byKey(const ValueKey('catalogue-fill-go')));
        await t.pumpAndSettle();
        expect(find.text('No product found for that.'), findsOneWidget);
      },
    );

    testWidgets(
      'Scan reads a product barcode into the fill and fills the form; no scanner = a message',
      (t) async {
        Object? asked;
        String? Function() answer = () => '9555123400011';
        const channel = MethodChannel('bukuresipi/qr');
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          asked = call.arguments;
          final a = answer();
          if (a == 'none') throw PlatformException(code: 'unavailable');
          return a;
        });
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await pump(t, const OwnerCataloguePage());
        await t.tap(find.byKey(const ValueKey('catalogue-add')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('catalogue-scan')));
        await t.pumpAndSettle();
        expect(asked, {'product': true});
        expect(repo.fills.last, '9555123400011');
        expect(find.widgetWithText(TextField, '9555123400011'), findsOneWidget);

        answer = () => 'none';
        await t.tap(find.byKey(const ValueKey('catalogue-scan')));
        await t.pumpAndSettle();
        expect(find.text("This phone can't scan codes."), findsOneWidget);
      },
    );

    testWidgets(
      'a fill that finds the product already: edit it instead of adding it again',
      (t) async {
        repo.fillAnswer = (
          name: 'Beras Faiza 5kg',
          brand: 'Faiza',
          brandIsNew: false,
          size: 5,
          unit: 'kg',
          ingredient: 'Beras putih',
          aiIngredient: false,
          source: 'https://world.openfoodfacts.org/product/9555035703828',
          maker: null,
          similar: [repo.productList.single],
        );
        await pump(t, const OwnerCataloguePage());
        await t.tap(find.byKey(const ValueKey('catalogue-add')));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('catalogue-fill')),
          '9555035703828',
        );
        await t.tap(find.byKey(const ValueKey('catalogue-fill-go')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('catalogue-similar-1')));
        await t.pumpAndSettle();
        expect(find.text('Add: Products'), findsNothing); // now editing it
        await t.tap(find.byKey(const ValueKey('catalogue-save')));
        await t.pumpAndSettle();
        expect(repo.savedRows.single.$1, 'products');
        expect(repo.savedRows.single.$2, 1); // the existing row, not a new one
      },
    );

    testWidgets('fill on an existing product fills only its empty fields', (
      t,
    ) async {
      repo.productList = const [
        CatalogueProduct(
          id: 7,
          name: 'Santan Kara Saya',
          brandId: 1,
          brand: 'Faiza',
        ),
      ];
      await pump(t, const OwnerCataloguePage());
      await t.tap(find.byKey(const ValueKey('catalogue-row-Santan Kara Saya')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('catalogue-fill')),
        '8992736000000',
      );
      await t.tap(find.byKey(const ValueKey('catalogue-fill-go')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('catalogue-save')));
      await t.pumpAndSettle();
      expect(repo.savedRows.single.$1, 'products');
      expect(repo.savedRows.single.$2, 7);
      expect(repo.savedRows.single.$3, {
        'name': 'Santan Kara Saya', // kept
        'ingredient': 'Santan', // was empty: filled
        'brandId': 1, // kept; the fill's new brand is not added
        'size': 200.0,
        'unit': 'ml',
      });
    });

    testWidgets(
      'a new product: brand from the list, ingredient from the suggestions, size and unit',
      (t) async {
        repo.catalogue = const ['Kicap'];
        await pump(t, const OwnerCataloguePage());
        await t.tap(find.byKey(const ValueKey('catalogue-add')));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('catalogue-name')),
          'Kicap Faiza 1L',
        );
        await t.tap(find.text('Brand'));
        await t.pumpAndSettle();
        await t.tap(find.text('Faiza').last);
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('catalogue-ingredient')),
          'kic',
        );
        await t.pumpAndSettle(const Duration(milliseconds: 300));
        await t.tap(find.widgetWithText(ActionChip, 'Kicap'));
        await t.enterText(find.byKey(const ValueKey('catalogue-size')), '1');
        await t.tap(find.text('Unit'));
        await t.pumpAndSettle();
        await t.tap(find.text('L'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('catalogue-save')));
        await t.pumpAndSettle();
        expect(repo.savedRows.single.$1, 'products');
        expect(repo.savedRows.single.$2, null);
        expect(repo.savedRows.single.$3, {
          'name': 'Kicap Faiza 1L',
          'ingredient': 'Kicap',
          'brandId': 1,
          'size': 1.0,
          'unit': 'L',
        });
      },
    );

    testWidgets('delete asks first; the rows for docs are shown', (t) async {
      await pump(t, const OwnerCataloguePage());
      await t.tap(find.byKey(const ValueKey('catalogue-row-Beras Faiza 5kg')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('catalogue-delete')));
      await t.pumpAndSettle();
      expect(repo.deletedRows, isEmpty);
      await t.tap(find.text('Delete').last);
      await t.pumpAndSettle();
      expect(repo.deletedRows, [('products', 1)]);
      expect(find.text('Deleted'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('catalogue-more')));
      await t.pumpAndSettle();
      await t.tap(find.text('Copy rows for docs'));
      await t.pumpAndSettle();
      expect(find.text('manufacturer.md'), findsOneWidget);
      expect(find.text('brand.md'), findsNothing);
      expect(find.text('| 122 | Kilang Baru |'), findsOneWidget);
    });
  });

  testWidgets(
    'a suggestion: added as a brand links it; dismiss removes the row',
    (t) async {
      repo.suggestionList = [
        (
          name: 'Kicap Mak Cik',
          ingredient: 'Kicap',
          recipes: 2,
          sample: '2 sudu kicap',
        ),
        (name: 'Santan Desa', ingredient: null, recipes: 1, sample: 'santan'),
      ];
      await pump(t, const OwnerCataloguePage());
      expect(
        find.text('Suggested'),
        findsNothing,
      ); // not a 4th tab: 3 fit a phone
      await t.tap(find.text('2 suggestions from recipes'));
      await t.pumpAndSettle();
      expect(find.text('Kicap · 2 recipes'), findsOneWidget);

      // Android back leaves the list for Products, not the page.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Suggested by recipe authors'), findsNothing);
      expect(find.text('2 suggestions from recipes'), findsOneWidget);
      await t.tap(find.text('2 suggestions from recipes'));
      await t.pumpAndSettle();

      await t.tap(find.text('Kicap Mak Cik'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add as a brand'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Kicap Mak Cik'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('catalogue-save')));
      await t.pumpAndSettle();
      final added = repo.brandList.last;
      expect(added.name, 'Kicap Mak Cik');
      expect(repo.resolvedSuggestions.single, (
        'Kicap Mak Cik',
        (kind: 'brand', id: added.id),
      ));
      expect(find.text('Linked to 2 lines'), findsOneWidget);
      expect(
        find.text('Kicap Mak Cik'),
        findsNothing,
      ); // resolved: gone from the tab

      await t.tap(find.text('Santan Desa'));
      await t.pumpAndSettle();
      await t.tap(find.text('Dismiss'));
      await t.pumpAndSettle();
      expect(repo.dismissed, ['Santan Desa']);
      expect(find.text('Santan Desa'), findsNothing);
    },
  );

  group('Owner > AI', () {
    testWidgets(
      'the default and every use are listed, an override shows its own line',
      (t) async {
        await pump(t, const OwnerAiPage());
        expect(find.text('Default'), findsWidgets);
        expect(
          find.text('DeepSeek v4.1 Flash · Off'),
          findsOneWidget,
        ); // the default row
        expect(find.text('Share: read a place post'), findsOneWidget);
        expect(find.text('Draft a place'), findsOneWidget);
        expect(find.text('DeepSeek v4.1 Flash · High'), findsOneWidget);
        expect(find.text('Read a receipt'), findsOneWidget);
      },
    );

    testWidgets(
      'a budget use above Off warns; it is saved; Use default clears another',
      (t) async {
        await pump(t, const OwnerAiPage());
        await t.tap(find.text('Share: read a place post'));
        await t.pumpAndSettle();
        expect(find.textContaining('can make it fail'), findsNothing);
        await t.tap(find.text('High'));
        await t.pumpAndSettle();
        expect(find.textContaining('can make it fail'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('ai-save')));
        await t.pumpAndSettle();
        expect(repo.aiSaved.single, (
          'share_extract',
          (
            provider: 'commandcode',
            model: 'deepseek/deepseek-v4.1-flash',
            reasoning: 'high',
          ),
        ));
        expect(find.text('DeepSeek v4.1 Flash · High'), findsNWidgets(2));

        await t.tap(find.text('Draft a place'));
        await t.pumpAndSettle();
        await t.tap(find.text('Use default'));
        await t.pumpAndSettle();
        expect(repo.aiCleared, ['place_draft']);
        expect(find.text('DeepSeek v4.1 Flash · High'), findsOneWidget);
      },
    );
  });
}
