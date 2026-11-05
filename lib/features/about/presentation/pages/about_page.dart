import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// What Bukuresipi is, how halal info works, the app version, and the links (website, credits, account deletion).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.version});

  /// Tests pass it; the app reads it from the installed package.
  final String? version;

  static Future<String> _installed() async {
    final i = await PackageInfo.fromPlatform();
    return '${i.version} (${i.buildNumber})';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    // The website's Malay pages are at /, English ones under /en.
    final site = l.localeName == 'en'
        ? 'https://bukuresipi.com/en'
        : 'https://bukuresipi.com';
    Widget point(IconData icon, String body) => NotebookRow(
      mark: Icon(icon, size: 20, color: nb.pandan),
      child: Text(body),
    );
    Widget link(IconData icon, String label, VoidCallback onTap) => NotebookRow(
      mark: Icon(icon, size: 20, color: nb.inkSoft),
      onTap: onTap,
      trailing: Icon(Icons.chevron_right, color: nb.inkSoft),
      child: Text(label),
    );

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.aboutTitle)),
      body: NotebookPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            NotebookRow(
              minHeight: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bukuresipi',
                    style: nb.hand.copyWith(fontSize: 30, color: nb.ink),
                  ),
                  Text(
                    l.aboutTagline,
                    style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                  ),
                ],
              ),
            ),
            NotebookHeading(l.aboutHowTitle),
            point(Icons.ios_share, l.aboutHowShare),
            point(Icons.menu_book_outlined, l.aboutHowBook),
            point(Icons.people_outline, l.aboutHowFamily),
            NotebookHeading(l.aboutHalalTitle),
            point(Icons.format_quote_outlined, l.aboutHalalBody),
            NotebookHeading(l.aboutMoreTitle),
            link(
              Icons.language,
              l.aboutWebsite,
              () => openLink(context, site, failed: l.openFailed),
            ),
            link(
              Icons.favorite_outline,
              l.creditsTitle,
              () => context.push('/credits'),
            ),
            link(
              Icons.delete_outline,
              l.aboutDeleteAccount,
              () =>
                  openLink(context, '$site/auth/delete', failed: l.openFailed),
            ),
            NotebookRow(
              mark: Icon(Icons.info_outline, size: 20, color: nb.inkSoft),
              child: FutureBuilder<String>(
                future: version == null ? _installed() : Future.value(version),
                builder: (context, s) => Text(
                  l.aboutVersion(s.data ?? '…'),
                  style: TextStyle(color: nb.inkSoft),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
