import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/log.dart';
import '../domain/caption_reader.dart';

/// Opens the post in an invisible WebView on the phone (the user's own connection, a real browser) and reads the
/// caption from the page: TikTok's page data, else (Facebook, Threads) the page's og:description, which there is the
/// whole caption. shortcut: depends on the sites' markup; when it changes this returns null and the share falls back
/// to "unreadable, try a screenshot". Update [script] then.
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

  /// Facebook and Threads: the page's og:description is the whole caption. Straight to it: their pages carry many
  /// large JSON blobs, and walking them looking for TikTok's `desc` is wasted work.
  static const metaScript = r'''
(() => {
  const meta = document.querySelector('meta[property="og:description"]')?.content
      || document.querySelector('meta[name="description"]')?.content;
  return meta && meta.trim() ? meta.trim() : null;
})()
''';

  /// Pages of the site that are not the post: their description is the site's ("Log in or sign up..."), not the
  /// caption. Read past them (the post loads after a redirect) or not at all.
  static bool notThePost(Uri at) => const [
    '/login',
    '/checkpoint',
    '/privacy/consent',
    '/cookie/consent',
  ].any(at.path.startsWith);

  @override
  Future<String?> read(String url) async {
    final site = phoneReadSite(Uri.tryParse(url)?.host ?? '');
    if (site == null) return null;
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
    // Read every 500 ms while on an https page of the same site (a share link redirects first: fb.watch, /share/r/),
    // until a caption appears or time runs out. A login or consent page is skipped ([notThePost]).
    final poll = Timer.periodic(_every, (_) async {
      final c = web;
      if (c == null || done.isCompleted) return;
      try {
        final at = await c.getUrl();
        if (at?.scheme != 'https' ||
            phoneReadSite(at!.host) != site ||
            notThePost(at)) {
          return;
        }
        final value = await c.evaluateJavascript(
          source: site == 'tiktok' ? script : metaScript,
        );
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
