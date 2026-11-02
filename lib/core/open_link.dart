import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app (browser, TikTok, Google Maps). Shows [failed] if nothing can open it.
Future<void> openLink(
  BuildContext context,
  String url, {
  required String failed,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
}
