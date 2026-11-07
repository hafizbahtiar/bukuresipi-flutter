import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/domain/review.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/reviews_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';
import '../places_fixtures.dart';

void main() {
  late FakePlaces repo;
  late PlacesController controller;

  setUp(() {
    repo = FakePlaces()
      ..reviewPage = ReviewPage(
        branchId: 'b-1',
        branchName: 'Kedai Sederhana',
        branchLabel: 'Kedai Sederhana Bangsar',
        rating: const RatingSummary(
          average: 4.3,
          count: 7,
          mine: 4,
          canRate: true,
          reviewCount: 1,
          myReview: false,
        ),
        reviews: [
          Review(
            id: 'r-1',
            stars: 4,
            text: 'Nasi lemak sedap.',
            author: 'Aina',
            mine: false,
            hidden: false,
            createdAt: DateTime.utc(2026, 11, 4),
            updatedAt: DateTime.utc(2026, 11, 4),
          ),
        ],
      );
    controller = PlacesController(repo);
  });

  Future<void> pump(WidgetTester t, {AuthController? auth}) async {
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          if (auth != null) ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('ms')],
          home: ReviewsPage(branchId: 'b-1'),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('lists reviews and records a helpful vote', (t) async {
    repo.voteResult = const ReviewVotes(up: 1, mine: ReviewVote.up);
    await pump(t);

    expect(find.text('Kedai Sederhana Bangsar'), findsOneWidget);
    expect(find.text('Nasi lemak sedap.'), findsOneWidget);
    expect(find.text('Aina'), findsOneWidget);

    await t.tap(find.byIcon(Icons.thumb_up_outlined));
    await t.pumpAndSettle();
    expect(repo.reviewVotes, [('r-1', ReviewVote.up)]);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('writes a review from the page', (t) async {
    await pump(t);
    await t.tap(find.text('Write a review'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Sedap, datang lagi.');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();

    expect(repo.reviewSaves, [('b-1', 4, 'Sedap, datang lagi.')]);
  });

  testWidgets('reports a review with a reason', (t) async {
    await pump(t);
    await t.tap(find.text('Report review'));
    await t.pumpAndSettle();
    expect(find.text('Why report this review?'), findsOneWidget);
    await t.tap(find.text('Offensive'));
    await t.tap(find.widgetWithText(FilledButton, 'Report review'));
    await t.pumpAndSettle();

    expect(repo.reviewReports.single.$1, 'r-1');
    expect(repo.reviewReports.single.$2, ReviewReason.offensive);
  });

  testWidgets(
    'a saver with an unconfirmed email is asked to confirm it, not to save',
    (t) async {
      final page = repo.reviewPage!;
      repo.reviewPage = ReviewPage(
        branchId: page.branchId,
        branchName: page.branchName,
        branchLabel: page.branchLabel,
        rating: const RatingSummary(
          average: 4.3,
          count: 7,
          mine: null,
          canRate: false,
          reviewCount: 1,
          myReview: false,
        ),
        reviews: page.reviews,
      );
      final auth = AuthController(
        FakeAuthRepository()
          ..session = true
          ..meResult = User(
            id: testUser.id,
            email: testUser.email,
            name: testUser.name,
            role: testUser.role,
            lang: testUser.lang,
            emailVerified: false,
          ),
      );
      await auth.restore();
      await pump(t, auth: auth);
      expect(find.text('Verify your email to review.'), findsOneWidget);
      expect(find.text('Save this place before reviewing it.'), findsNothing);
    },
  );
}
