import 'package:bukuresipi_flutter/features/shares/domain/share.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/recent_shares.dart';
import 'package:flutter_test/flutter_test.dart';

import 'share_intake_test.dart' show FakeShares;

Share s(String id, String status, {List<String> gaps = const []}) => Share(
  id: id,
  status: status,
  kind: 'restaurant',
  gaps: gaps,
  placeId: status == 'done' ? 'r-$id' : null,
);

void main() {
  test('shares still being read and failed ones are listed; a share that finishes reloads the book', () async {
    final repo = FakeShares()
      ..recentList = [s('a', 'processing'), s('b', 'failed'), s('c', 'done')];
    var reloads = 0;
    final recent = RecentShares(
      repo,
      onFinished: () async => reloads++,
      every: const Duration(hours: 1),
    );
    await recent.load();
    expect(recent.reading.map((x) => x.id), ['a']);
    expect(recent.failed.map((x) => x.id), ['b']);
    expect(reloads, 0);

    repo.recentList = [s('a', 'done'), s('b', 'failed'), s('c', 'done')];
    await recent.load();
    expect(recent.reading, isEmpty);
    expect(reloads, 1);
    recent.dispose();
  });

  testWidgets(
    'a share still reading after two minutes is asked 6x less; a new share goes back to quick',
    (t) async {
      final repo = FakeShares()..recentList = [s('a', 'pending')];
      final recent = RecentShares(
        repo,
        onFinished: () async {},
        every: const Duration(seconds: 5),
      );
      await recent.load();
      for (var i = 0; i < 24; i++) {
        await t.pump(const Duration(seconds: 5));
      }
      final quick = repo.recentReads;
      await t.pump(const Duration(seconds: 25));
      expect(repo.recentReads, quick);
      await t.pump(const Duration(seconds: 5));
      expect(repo.recentReads, quick + 1);

      repo.recentList = [s('a', 'pending'), s('b', 'pending')];
      await recent.load();
      final fresh = repo.recentReads;
      await t.pump(const Duration(seconds: 5));
      expect(repo.recentReads, fresh + 1);
      recent.dispose();
    },
  );

  test('a failed share can be retried and dismissed', () async {
    final repo = FakeShares()..recentList = [s('a', 'failed')];
    final recent = RecentShares(repo, onFinished: () async {});
    await recent.load();
    expect(recent.failed.map((x) => x.id), ['a']);

    await recent.retry('a');
    expect(repo.retried, ['a']);
    expect(repo.recentReads, 2);

    await recent.dismiss('a');
    expect(repo.dismissed, ['a']);
    expect(recent.failed, isEmpty);
    recent.dispose();
  });

  test('a post the API could not read counts as failed', () async {
    final repo = FakeShares()
      ..recentList = [
        s('a', 'done', gaps: ['unreadable']),
      ];
    final recent = RecentShares(repo, onFinished: () async {});
    await recent.load();
    expect(recent.failed.map((x) => x.id), ['a']);
    recent.dispose();
  });

  test('a finished share marks its restaurant as fresh (the book highlights it); a post with nothing in it is listed', () async {
    final repo = FakeShares()..recentList = [s('a', 'processing')];
    final recent = RecentShares(
      repo,
      onFinished: () async {},
      every: const Duration(hours: 1),
    );
    await recent.load();
    expect(recent.isFresh('r-a'), isFalse);
    repo.recentList = [
      s('a', 'done'),
      const Share(id: 'z', status: 'done', kind: 'other'),
    ];
    await recent.load();
    expect(recent.isFresh('r-a'), isTrue);
    expect(recent.failed.map((x) => x.id), ['z']);
    expect(recent.failed.single.nothingFound, isTrue);
    recent.dispose();
  });
}
