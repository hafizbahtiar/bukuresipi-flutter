import 'package:bukuresipi_flutter/features/shares/data/webview_caption_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login, checkpoint and consent pages are not the post', () {
    for (final p in [
      '/login/',
      '/login.php',
      '/checkpoint/123',
      '/privacy/consent/x',
      '/cookie/consent',
    ]) {
      expect(
        WebViewCaptionReader.notThePost(Uri.parse('https://m.facebook.com$p')),
        isTrue,
        reason: p,
      );
    }
    for (final p in ['/reel/1/', '/share/r/abc/', '/@a/post/1']) {
      expect(
        WebViewCaptionReader.notThePost(
          Uri.parse('https://www.facebook.com$p'),
        ),
        isFalse,
        reason: p,
      );
    }
  });
}
