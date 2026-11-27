import 'package:extended_image/extended_image.dart';
import 'package:bukuresipi_flutter/features/notifications/data/notifications_api.dart';
import 'package:bukuresipi_flutter/features/notifications/domain/inbox.dart';
import 'package:bukuresipi_flutter/features/notifications/presentation/pages/notifications_page.dart';
import 'package:bukuresipi_flutter/features/notifications/presentation/widgets/inbox_bell.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeApi extends NotificationsApi {
  _FakeApi(this.items, this.unread) : super(Dio());
  List<InboxItem> items;
  int unread;
  int seenCalls = 0;
  @override
  Future<({List<InboxItem> items, int unread})> list() async =>
      (items: items, unread: unread);
  final hidden = <int>[];
  @override
  Future<void> hide(int id) async {
    hidden.add(id);
    items = [
      for (final n in items)
        if (n.id != id) n,
    ];
  }

  @override
  Future<void> seen() async {
    seenCalls++;
    unread = 0;
  }
}

InboxItem item(String title, Map<String, String> data, {bool owner = false}) =>
    InboxItem(
      id: title.hashCode,
      title: title,
      body: 'Body of $title',
      data: data,
      fromOwner: owner,
      createdAt: DateTime(2026, 11, 20, 9, 30),
    );

void main() {
  Future<void> pump(WidgetTester t, _FakeApi api, {Widget? home}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => home ?? NotificationsPage(api: api),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => NotificationsPage(api: api),
        ),
        GoRoute(
          path: '/badges',
          builder: (_, _) => const Scaffold(body: Text('BADGES')),
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'lists the inbox, marks it read, a tap opens what the push opens',
    (t) async {
      final api = _FakeApi([
        item('New badge', {'type': 'badge'}),
        item('Hai', {'type': 'message'}, owner: true),
      ], 1);
      await pump(t, api);
      expect(find.text('New badge'), findsOneWidget);
      expect(find.text('Hai'), findsOneWidget);
      expect(api.seenCalls, 1);
      await t.tap(find.text('Hai')); // the owner's message: all of it is here
      await t.pumpAndSettle();
      expect(find.text('BADGES'), findsNothing);
      await t.tap(find.text('New badge'));
      await t.pumpAndSettle();
      expect(find.text('BADGES'), findsOneWidget);
    },
  );

  testWidgets('empty: says so; nothing new = not marked again', (t) async {
    final api = _FakeApi([], 0);
    await pump(t, api);
    expect(find.byKey(const ValueKey('inbox-empty')), findsOneWidget);
    expect(api.seenCalls, 0);
  });

  testWidgets(
    'the bell: a dot while something is new; gone after the inbox is opened',
    (t) async {
      final api = _FakeApi([
        item('New badge', {'type': 'badge'}),
      ], 1);
      await pump(
        t,
        api,
        home: Scaffold(
          appBar: AppBar(actions: [InboxBell(api: api)]),
        ),
      );
      Badge badge() => t.widget<Badge>(
        find.descendant(
          of: find.byKey(const ValueKey('feed-inbox')),
          matching: find.byType(Badge),
        ),
      );
      expect(badge().isLabelVisible, isTrue);
      await t.tap(find.byKey(const ValueKey('feed-inbox')));
      await t.pumpAndSettle();
      expect(find.text('New badge'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(badge().isLabelVisible, isFalse);
    },
  );

  testWidgets(
    'the bell is read again when a push arrives in the open app and when the app comes back',
    (t) async {
      final api = _FakeApi([], 0);
      await pump(
        t,
        api,
        home: Scaffold(
          appBar: AppBar(actions: [InboxBell(api: api)]),
        ),
      );
      bool dot() => t
          .widget<Badge>(
            find.descendant(
              of: find.byKey(const ValueKey('feed-inbox')),
              matching: find.byType(Badge),
            ),
          )
          .isLabelVisible;
      expect(dot(), isFalse);
      api.unread = 1;
      inboxChanged.value++; // app.dart: a push arrived while the app is open
      await t.pumpAndSettle();
      expect(dot(), isTrue);
      api.unread = 0;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
      await t.pumpAndSettle();
      expect(dot(), isFalse);
    },
  );

  testWidgets('pull to refresh reads the inbox again', (t) async {
    final api = _FakeApi([
      item('Old', {'type': 'badge'}),
    ], 0);
    await pump(t, api);
    api.items = [
      item('New one', {'type': 'badge'}),
    ];
    await t.fling(find.text('Old'), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('New one'), findsOneWidget);
  });

  testWidgets(
    'a row is removed from the inbox from its menu (only for this user)',
    (t) async {
      final api = _FakeApi([
        item('Keep', {'type': 'badge'}),
        item('Gone', {'type': 'message'}, owner: true),
      ], 0);
      await pump(t, api);
      await t.longPress(find.byKey(const ValueKey('inbox-1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(api.hidden, ['Gone'.hashCode]);
      expect(find.text('Gone'), findsNothing);
      expect(find.text('Keep'), findsOneWidget);
      expect(find.text('Removed'), findsOneWidget); // the snackbar
    },
  );

  testWidgets('a row with a photo shows it under its text', (t) async {
    final api = _FakeApi([
      InboxItem(
        id: 1,
        title: 'Raya',
        body: 'Selamat hari raya!',
        data: const {'type': 'message'},
        fromOwner: true,
        image: 'https://api.test/api/v1/notifications/image/abc',
        createdAt: DateTime(2026, 11, 20, 9),
      ),
      item('No photo', {'type': 'badge'}),
    ], 0);
    await pump(t, api);
    expect(find.byKey(const ValueKey('inbox-image-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-image-1')), findsNothing);
    // Kept on disk: a phone downloads a photo once, not at every app open (each download is a Worker request).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ExtendedImage &&
            w.image is ExtendedNetworkImageProvider &&
            (w.image as ExtendedNetworkImageProvider).cache,
      ),
      findsOneWidget,
    );
  });
}
