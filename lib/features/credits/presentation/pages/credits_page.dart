import 'package:flutter/material.dart';

import '../../../../core/utils/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// Every data source, service and open-source credit the app relies on, the licences, and who makes it.
class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final map = [
      _Credit(
        icon: Icons.layers_outlined,
        title: l.creditsOpenFreeMap,
        detail: l.creditsOpenFreeMapDetail,
        url: 'https://openfreemap.org',
      ),
      _Credit(
        icon: Icons.map_outlined,
        title: l.creditsOpenMapTiles,
        detail: l.creditsOpenMapTilesDetail,
        url: 'https://openmaptiles.org',
      ),
      _Credit(
        icon: Icons.public,
        title: l.creditsOsm,
        detail: l.creditsOsmDetail,
        url: 'https://www.openstreetmap.org/copyright',
      ),
      _Credit(
        icon: Icons.map_outlined,
        title: l.creditsMapLibre,
        detail: l.creditsMapLibreDetail,
        url: 'https://maplibre.org',
      ),
    ];
    final places = [
      _Credit(
        icon: Icons.place_outlined,
        title: l.creditsOverture,
        detail: l.creditsOvertureDetail,
        url: 'https://overturemaps.org',
      ),
      _Credit(
        icon: Icons.search,
        title: l.creditsNominatim,
        detail: l.creditsNominatimDetail,
        url: 'https://nominatim.org',
      ),
      _Credit(
        icon: Icons.search,
        title: l.creditsPhoton,
        detail: l.creditsPhotonDetail,
        url: 'https://photon.komoot.io',
      ),
      _Credit(
        icon: Icons.travel_explore,
        title: l.creditsHere,
        detail: l.creditsHereDetail,
        url: 'https://www.here.com',
      ),
      _Credit(
        icon: Icons.travel_explore,
        title: l.creditsParallel,
        detail: l.creditsParallelDetail,
        url: 'https://parallel.ai',
      ),
      _Credit(
        icon: Icons.travel_explore,
        title: l.creditsTinyFish,
        detail: l.creditsTinyFishDetail,
        url: 'https://www.tinyfish.ai',
      ),
      _Credit(
        icon: Icons.storefront_outlined,
        title: l.creditsGrab,
        detail: l.creditsGrabDetail,
        url: 'https://aws.amazon.com/location/',
      ),
      _Credit(
        icon: Icons.markunread_mailbox_outlined,
        title: l.creditsPostcodes,
        detail: l.creditsPostcodesDetail,
        url: 'https://www.npmjs.com/package/malaysia-postcodes',
      ),
      _Credit(
        icon: Icons.verified_outlined,
        title: l.creditsJakim,
        detail: l.creditsJakimDetail,
        url: 'https://www.halal.gov.my',
      ),
    ];
    final type = [
      _Credit(
        icon: Icons.font_download_outlined,
        title: l.creditsFonts,
        detail: l.creditsFontsDetail,
        url: 'https://fonts.google.com',
      ),
    ];
    final app = [
      _Credit(
        icon: Icons.flutter_dash,
        title: l.creditsFlutter,
        detail: l.creditsFlutterDetail,
        url: 'https://flutter.dev',
      ),
      _Credit(
        icon: Icons.cloud_outlined,
        title: l.creditsCloudflare,
        detail: l.creditsCloudflareDetail,
        url: 'https://www.cloudflare.com',
      ),
      _Credit(
        icon: Icons.auto_awesome_outlined,
        title: l.creditsDeepSeek,
        detail: l.creditsDeepSeekDetail,
        url: 'https://commandcode.ai',
      ),
    ];
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.creditsTitle)),
      body: NotebookPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _Dedication(),
            Padding(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 0),
              child: Text(
                l.creditsIntro,
                style: text.bodyMedium?.copyWith(color: nb.inkSoft),
              ),
            ),
            NotebookHeading(l.creditsMap),
            for (final credit in map) _CreditRow(credit: credit),
            NotebookHeading(l.creditsPlaces),
            for (final credit in places) _CreditRow(credit: credit),
            NotebookHeading(l.creditsTypography),
            for (final credit in type) _CreditRow(credit: credit),
            NotebookHeading(l.creditsApp),
            for (final credit in app) _CreditRow(credit: credit),
            NotebookRow(
              key: const Key('credits-licenses'),
              mark: Icon(
                Icons.description_outlined,
                size: 18,
                color: nb.inkSoft,
              ),
              trailing: Icon(Icons.chevron_right, color: nb.inkSoft),
              // Flutter's own page: every package's licence text, which MIT/BSD/Apache ask us to carry.
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Bukuresipi',
                applicationLegalese:
                    '© ${DateTime.now().year} Tri Digital Niaga',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.creditsLicenses,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l.creditsLicensesDetail,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                notebookGutter + 10,
                24,
                20,
                16,
              ),
              child: Text(
                '${l.dataCredits}\n\n${l.creditsMaker}',
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who the app was built for, first, as on the website's credits page.
class _Dedication extends StatelessWidget {
  const _Dedication();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final line = nb.hand.copyWith(fontSize: 20, height: 1.4, color: nb.ink);
    return Padding(
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 12, 20, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: nb.paper,
          border: Border(
            left: BorderSide(color: nb.margin, width: 3),
            top: BorderSide(color: nb.line),
            right: BorderSide(color: nb.line),
            bottom: BorderSide(color: nb.line),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.creditsDedicationKicker,
                  style: line.copyWith(fontSize: 24, color: nb.margin),
                ),
                const SizedBox(height: 8),
                Text(l.creditsDedication1, style: line),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Text(l.creditsDedication2, style: line),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: ExcludeSemantics(
                child: Text(
                  '♥',
                  style: line.copyWith(fontSize: 24, color: nb.margin),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Credit {
  const _Credit({
    required this.icon,
    required this.title,
    required this.detail,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String url;
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit});

  final _Credit credit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return NotebookRow(
      mark: Icon(credit.icon, size: 18, color: nb.inkSoft),
      trailing: Icon(Icons.open_in_new, size: 15, color: nb.inkSoft),
      onTap: () => openLink(context, credit.url, failed: l.openFailed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            credit.title,
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            credit.detail,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}
