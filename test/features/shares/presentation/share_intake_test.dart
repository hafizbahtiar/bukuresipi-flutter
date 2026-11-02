import 'dart:async';

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

  @override
  Future<String> submitLink(String url, {String? caption}) async {
    if (error != null) throw error!;
    await gate?.future;
    sent.add('link:$url');
    captions.add(caption);
    return 'share-1';
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

  @override
  Future<void> dismiss(String id) async => dismissed.add(id);

  @override
  Future<List<Share>> recent() async {
    recentReads++;
    return recentList;
  }
}

class FakeCaptions implements CaptionReader {
  String? caption;
  final asked = <String>[];

  @override
  Future<String?> read(String url) async {
    asked.add(url);
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

  test('two shares arriving while the first is sending are both sent', () async {
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

  test('a TikTok link goes out with the caption read on the phone', () async {
    await start();
    captions.caption = 'Resepi ayam masak merah';
    await share([const Incoming.text('https://vt.tiktok.com/ZS1/')]);
    expect(captions.asked, ['https://vt.tiktok.com/ZS1/']);
    expect(shares.captions, ['Resepi ayam masak merah']);
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

  test('a caption the phone could not read still sends the link', () async {
    await start();
    await share([const Incoming.text('https://www.tiktok.com/@a/video/1')]);
    expect(shares.sent, ['link:https://www.tiktok.com/@a/video/1']);
    expect(shares.captions, [null]);
  });
}
