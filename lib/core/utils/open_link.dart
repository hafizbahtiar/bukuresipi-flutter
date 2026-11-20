import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app (browser, TikTok, Google Maps). Shows [failed] if nothing can open it.
/// Web links only: the URL comes from shared posts and pages, so `intent:`, `tel:` and the like are refused.
Future<void> openLink(
  BuildContext context,
  String url, {
  required String failed,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url);
  final web = uri != null && (uri.isScheme('https') || uri.isScheme('http'));
  final ok =
      web &&
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
}
