import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/log.dart';
import '../domain/caption_reader.dart';

/// Opens the post in an invisible WebView on the phone (the user's own connection, a real browser) and reads the
/// caption from the page. shortcut: depends on TikTok's page markup; when it changes this returns null and the share
/// falls back to "unreadable, try a screenshot". Update [script] then.
class WebViewCaptionReader implements CaptionReader {
  static const _timeout = Duration(seconds: 12);
  static const _every = Duration(milliseconds: 500);

  /// Caption from the page: the post's `desc` anywhere in TikTok's page data (its layout differs between the web app
  /// and the share page), else og:description, else the title without " | TikTok" (cut short by TikTok).
  static const script = r'''
(() => {
  const seen = new Set();
  const find = (o, depth) => {
    if (!o || typeof o !== 'object' || depth > 12 || seen.has(o)) return null;
    seen.add(o);
    if (typeof o.desc === 'string' && o.desc.trim() && (o.author || o.video || o.stats || o.id)) {
      const by = typeof o.author === 'object' ? (o.author.nickname || o.author.uniqueId) : o.author;
      return [o.desc.trim(), by].filter(Boolean).join('\n');
    }
    for (const v of Object.values(o)) { const r = find(v, depth + 1); if (r) return r; }
    return null;
  };
  for (const s of document.querySelectorAll('script[type="application/json"]')) {
    try { const r = find(JSON.parse(s.textContent), 0); if (r) return r; } catch (e) {}
  }
  const meta = document.querySelector('meta[property="og:description"]')?.content
      || document.querySelector('meta[name="description"]')?.content;
  if (meta && meta.trim()) return meta.trim();
  const title = document.title.replace(/\s*\|\s*TikTok\s*$/, '').trim();
  return title && !/^TikTok\b/.test(title) ? title : null;
})()
''';

  @override
  Future<String?> read(String url) async {
    final done = Completer<String?>();
    InAppWebViewController? web;
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: true,
        blockNetworkImage: true,
        useShouldOverrideUrlLoading: true,
      ),
      onWebViewCreated: (c) => web = c,
      // TikTok's page jumps to snssdk1180:// ("open in the TikTok app"); a WebView cannot open that and shows an
      // error page instead of the post. Stay on https pages only.
      shouldOverrideUrlLoading: (_, action) async =>
          action.request.url?.scheme == 'https'
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL,
    );
    // Read every 500 ms while on an https TikTok page, until a caption appears or time runs out.
    final poll = Timer.periodic(_every, (_) async {
      final c = web;
      if (c == null || done.isCompleted) return;
      try {
        final at = await c.getUrl();
        if (at?.scheme != 'https' ||
            !(at!.host == 'tiktok.com' || at.host.endsWith('.tiktok.com'))) {
          return;
        }
        final value = await c.evaluateJavascript(source: script);
        if (value is String && value.trim().isNotEmpty && !done.isCompleted) {
          done.complete(value.trim());
        }
      } catch (_) {
        // Page between loads: the next tick tries again.
      }
    });
    try {
      await view.run();
      return await done.future.timeout(_timeout, onTimeout: () => null);
    } catch (e) {
      log('caption: could not read ($e)');
      return null;
    } finally {
      poll.cancel();
      await view.dispose();
    }
  }
}
