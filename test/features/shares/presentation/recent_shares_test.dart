import 'package:bukuresipi_flutter/features/shares/domain/share.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/recent_shares.dart';
import 'package:flutter_test/flutter_test.dart';

import 'share_intake_test.dart' show FakeShares;

Share s(String id, String status, {List<String> gaps = const []}) =>
    Share(id: id, status: status, kind: 'restaurant', gaps: gaps);

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
}
