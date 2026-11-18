import 'dart:async';
import 'dart:typed_data';

import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/shares/domain/caption_reader.dart';
import 'package:bukuresipi_flutter/features/shares/domain/share.dart';
import 'package:bukuresipi_flutter/features/shares/domain/share_repository.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/share_intake.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes.dart';

class FakeShares implements ShareRepository {
  final sent = <String>[];
  final captions = <String?>[];
  Object? error;
  Completer<void>? gate;

  /// The API answered from an earlier read of the post.
  bool reused = false;

  @override
  Future<({String id, bool done})> submitLink(
    String url, {
    String? caption,
  }) async {
    if (error != null) throw error!;
    await gate?.future;
    sent.add('link:$url');
    captions.add(caption);
    return (id: 'share-1', done: reused);
  }

  @override
  Future<String> submitImage(String path) async {
    if (error != null) throw error!;
    await gate?.future;
    sent.add('image:$path');
    return 'share-2';
  }

  @override
  Future<Share> get(String id) async => throw UnimplementedError();

  List<Share> recentList = [];
  int recentReads = 0;
  final retried = <String>[];
  final dismissed = <String>[];

  @override
  Future<void> retry(String id) async => retried.add(id);

  /// (share id, caption) sent after the link.
  final added = <(String, String)>[];
  @override
  Future<void> addCaption(String id, String caption) async =>
      added.add((id, caption));

  @override
  Future<void> dismiss(String id) async => dismissed.add(id);

  Uint8List? imageBytes;
  @override
  Future<Uint8List?> image(String id) async => imageBytes;

  @override
  Future<List<Share>> recent() async {
    recentReads++;
    return recentList;
  }
}

class FakeCaptions implements CaptionReader {
  String? caption;
  Completer<void>? gate;
  final asked = <String>[];

  @override
  Future<String?> read(String url) async {
    asked.add(url);
    await gate?.future;
    return caption;
  }
}

class FakeIncoming implements IncomingShares {
  final controller = StreamController<List<Incoming>>.broadcast();
  List<Incoming> first = const [];

  @override
  Future<List<Incoming>> initial() async => first;
  @override
  Stream<List<Incoming>> get stream => controller.stream;
  @override
  void reset() {}
}

void main() {
  test('firstLink finds the https link inside shared text', () {
    expect(
      firstLink('Tengok ni! https://vt.tiktok.com/ZS123/ sedap'),
      'https://vt.tiktok.com/ZS123/',
    );
    expect(firstLink('https://youtu.be/abc.'), 'https://youtu.be/abc');
    expect(firstLink('no link here'), isNull);
    expect(firstLink('http://insecure.example.com'), isNull);
  });

  late FakeShares shares;
  late FakeIncoming incoming;
  late FakeCaptions captions;
  late FakeAuthRepository authRepo;
  late AuthController auth;
  late List<String> shown;

  Future<ShareIntake> start({bool signedIn = true}) async {
    shares = FakeShares();
    incoming = FakeIncoming();
    captions = FakeCaptions();
    authRepo = FakeAuthRepository()..session = signedIn;
    auth = AuthController(authRepo);
    await auth.restore();
    shown = [];
    final intake = ShareIntake(incoming, shares, auth, captions)
      ..onShow = () => shown.add('show');
    await intake.start();
    return intake;
  }

  Future<void> share(List<Incoming> items) async {
    incoming.controller.add(items);
    await Future<void>.delayed(Duration.zero);
  }

  test('signed in: a shared link is sent and its share id kept', () async {
    final intake = await start();
    await share([
      const Incoming.text('Cuba resipi ni https://www.instagram.com/p/xyz/'),
    ]);
    expect(shares.sent, ['link:https://www.instagram.com/p/xyz/']);
    expect(
      intake.state,
      isA<ShareAccepted>().having((s) => s.id, 'id', 'share-1'),
    );
    expect(shown, isNotEmpty);
  });

  test(
    'two shares arriving while the first is sending are both sent',
    () async {
      final intake = await start();
      final gate = Completer<void>();
      shares.gate = gate;
      await share([const Incoming.text('https://www.tiktok.com/@a/video/1')]);
      expect(shares.sent, isEmpty);
      await share([const Incoming.text('https://www.tiktok.com/@a/video/2')]);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(shares.sent, [
        'link:https://www.tiktok.com/@a/video/1',
        'link:https://www.tiktok.com/@a/video/2',
      ]);
      expect(intake.state, isA<ShareAccepted>());
    },
  );

  test('a share from the + sheet stays in the app; one from another app goes back to it', () async {
    final intake = await start();
    intake.add(const Incoming.text('https://www.instagram.com/p/xyz/'));
    await Future<void>.delayed(Duration.zero);
    expect(intake.state, isA<ShareAccepted>());
    expect(intake.fromApp, isTrue);
    await share([const Incoming.text('https://www.instagram.com/p/abc/')]);
    expect(intake.fromApp, isFalse);
  });

  test('a shared image is uploaded', () async {
    await start();
    await share([const Incoming.image('/tmp/shot.jpg')]);
    expect(shares.sent, ['image:/tmp/shot.jpg']);
  });

  test(
    'signed out: the share waits, then goes out right after sign in',
    () async {
      final intake = await start(signedIn: false);
      await share([const Incoming.text('https://www.tiktok.com/@a/video/1')]);
      expect(shares.sent, isEmpty);
      expect(intake.state, isA<ShareWaitingForLogin>());
      await auth.login('a@example.com', 'pw');
      await Future<void>.delayed(Duration.zero);
      expect(shares.sent, ['link:https://www.tiktok.com/@a/video/1']);
    },
  );

  test('our own email links (App Links) are not shares', () async {
    final intake = await start();
    await share([
      const Incoming.url('https://bukuresipi.com/auth/reset?token=x'),
    ]);
    expect(shares.sent, isEmpty);
    expect(intake.state, isA<ShareIdle>());
    expect(shown, isEmpty);
  });

  test('text without a link says so and sends nothing', () async {
    final intake = await start();
    await share([const Incoming.text('just words')]);
    expect(shares.sent, isEmpty);
    expect(
      intake.state,
      isA<ShareFailed>().having((s) => s.code, 'code', 'no_link'),
    );
  });

  test('the API refusing (daily limit) is shown, not thrown', () async {
    final intake = await start();
    shares.error = const ApiException('daily_limit', status: 429);
    await share([const Incoming.text('https://www.facebook.com/x/posts/1')]);
    expect(
      intake.state,
      isA<ShareFailed>().having((s) => s.code, 'code', 'daily_limit'),
    );
  });

  test('a TikTok link goes out at once; the caption the phone reads follows, without holding the share up', () async {
    final intake = await start();
    captions
      ..caption = 'Resepi ayam masak merah'
      ..gate = Completer<void>(); // the WebView is still loading the post
    await share([const Incoming.text('https://vt.tiktok.com/ZS1/')]);
    expect(shares.sent, ['link:https://vt.tiktok.com/ZS1/']);
    expect(shares.captions, [null]);
    expect(intake.state, isA<ShareAccepted>()); // not "Sending" for 12 s
    expect(shares.added, isEmpty);
    captions.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(shares.added, [('share-1', 'Resepi ayam masak merah')]);
  });

  test('Facebook and Threads links are read on the phone too (Meta refuses the server); not lookalike hosts', () async {
    await start();
    captions.caption = 'Ada gang Rawang sini ke. 📍 Ah Tender Fish N Chip';
    await share([
      const Incoming.text('https://www.facebook.com/share/r/1HVbEJjdmp/'),
    ]);
    await share([const Incoming.text('https://fb.watch/abc/')]);
    await share([const Incoming.text('https://www.threads.com/@a/post/1')]);
    expect(captions.asked, [
      'https://www.facebook.com/share/r/1HVbEJjdmp/',
      'https://fb.watch/abc/',
      'https://www.threads.com/@a/post/1',
    ]);
    expect(shares.added, hasLength(3));
    expect(phoneReadSite('notfacebook.com'), isNull);
    expect(phoneReadSite('m.facebook.com'), 'facebook');
  });

  test(
    'other links are sent as they are (no page load on the phone)',
    () async {
      await start();
      await share([const Incoming.text('https://www.youtube.com/watch?v=1')]);
      expect(captions.asked, isEmpty);
      expect(shares.captions, [null]);
    },
  );

  test(
    'a post the API already read (reused) is not loaded on the phone',
    () async {
      await start();
      shares.reused = true;
      captions.caption = 'Resepi ayam masak merah';
      await share([const Incoming.text('https://www.tiktok.com/@a/video/1')]);
      expect(captions.asked, isEmpty);
      expect(shares.added, isEmpty);
    },
  );

  test('captions are read one page at a time', () async {
    await start();
    captions
      ..caption = 'Ah Tender'
      ..gate = Completer<void>();
    await share([const Incoming.text('https://www.tiktok.com/@a/video/1')]);
    await share([const Incoming.text('https://www.tiktok.com/@a/video/2')]);
    await Future<void>.delayed(Duration.zero);
    expect(shares.sent, hasLength(2)); // both links went at once
    expect(captions.asked, [
      'https://www.tiktok.com/@a/video/1',
    ]); // the second page waits
    captions.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(captions.asked, hasLength(2));
    expect(shares.added, hasLength(2));
  });

  test(
    'a caption the phone could not read: the link is sent, nothing follows',
    () async {
      await start();
      await share([const Incoming.text('https://www.tiktok.com/@a/video/1')]);
      expect(shares.sent, ['link:https://www.tiktok.com/@a/video/1']);
      expect(shares.added, isEmpty);
    },
  );
}
