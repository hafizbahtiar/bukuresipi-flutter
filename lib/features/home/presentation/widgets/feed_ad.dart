import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/ads/ads.dart';
import '../../../../core/utils/log.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import 'feed_card.dart';

/// One Home ad card, in a feed grid cell like a [FeedCard]. Drawn by Android (FeedAdFactory.kt, factory "feedCard"):
/// AdMob ads cannot be Flutter widgets. Loads when built (the grid builds cells near the screen), shows the card
/// skeleton until then, and calls [onFailed] when no ad came, so the feed drops the cell.
class FeedAd extends StatefulWidget {
  const FeedAd({super.key, required this.onFailed});

  final VoidCallback onFailed;

  @override
  State<FeedAd> createState() => _FeedAdState();
}

class _FeedAdState extends State<FeedAd> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ad ??= _load(); // needs the theme and language: not in initState
  }

  NativeAd _load() {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return NativeAd(
      adUnitId: Ads.unitId,
      factoryId: 'feedCard',
      request: const AdRequest(keywords: ['food', 'recipe', 'restaurant']),
      // Images only: the card's 4:3 photo box (video is also off on the ad unit).
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.landscape,
      ),
      customOptions: {
        'label': AppLocalizations.of(context).feedAdLabel,
        'paper': nb.paper.toARGB32(),
        'line': nb.line.toARGB32(),
        'ink': nb.ink.toARGB32(),
        'inkSoft': nb.inkSoft.toARGB32(),
        'pandan': nb.pandan.toARGB32(),
        'pandanDeep': nb.pandanDeep.toARGB32(),
        'placeholder': Theme.of(context).colorScheme.surfaceContainerHigh
            .toARGB32(),
        // Unscaled sizes: Android scales sp by the same system font size Flutter's textScaler follows.
        'labelSize': text.labelSmall?.fontSize ?? 11,
        'titleSize': text.titleSmall?.fontSize ?? 14,
        'bodySize': text.bodySmall?.fontSize ?? 12,
        'ctaSize': text.labelMedium?.fontSize ?? 12,
      },
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, e) {
          log('ads: no ad (${e.code} ${e.message})');
          ad.dispose();
          if (mounted) widget.onFailed();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _loaded
      ? AdWidget(ad: _ad!)
      : const FeedCardSkeleton(key: ValueKey('feed-ad-loading'));
}
