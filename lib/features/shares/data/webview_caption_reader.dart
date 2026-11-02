import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/log.dart';
import '../domain/caption_reader.dart';

/// Opens the post in an invisible WebView on the phone (the user's own connection, a real browser) and reads the
/// caption from the page. shortcut: depends on TikTok's page markup; when it changes this returns null and the share
/// falls back to "unreadable, try a screenshot". Update [_script] then.
class WebViewCaptionReader implements CaptionReader {
  static const _timeout = Duration(seconds: 12);

  // TikTok puts the video data in a JSON <script>; og:description is the fallback.
  static const _script = '''
(() => {
  try {
    const raw = document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.textContent;
    const item = raw && JSON.parse(raw)?.__DEFAULT_SCOPE__?.['webapp.video-detail']?.itemInfo?.itemStruct;
    if (item?.desc) return [item.desc, item.author?.nickname].filter(Boolean).join('\\n');
  } catch (e) {}
  return document.querySelector('meta[property="og:description"]')?.content
      || document.querySelector('meta[name="description"]')?.content || null;
})()
''';

  @override
  Future<String?> read(String url) async {
    final done = Completer<String?>();
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: true,
        blockNetworkImage: true,
      ),
      onLoadStop: (controller, _) async {
        // The page may fill in after load: look a few times.
        for (var i = 0; i < 6 && !done.isCompleted; i++) {
          final value = await controller.evaluateJavascript(source: _script);
          if (value is String && value.trim().isNotEmpty) {
            return done.complete(value.trim());
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      },
    );
    try {
      await view.run();
      return await done.future.timeout(_timeout, onTimeout: () => null);
    } catch (e) {
      log('caption: could not read ($e)');
      return null;
    } finally {
      await view.dispose();
    }
  }
}
