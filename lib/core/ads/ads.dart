import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../log.dart';

/// AdMob for the Home feed's ad cards (design: bukuresipi-hono docs/superpowers/specs/2026-11-17-home-ads-design.md).
/// Android only (iOS needs its own AdMob app and a Swift layout).
class Ads {
  Ads._();

  /// Google's test native ad unit: always fills, never pays, safe to tap.
  static const _testUnit = 'ca-app-pub-3940256099942544/2247696110';

  /// The real native ad unit (AdMob > Bukuresipi > Ad units, Native advanced, images only). Used only by release
  /// builds; debug/profile always get [_testUnit], so our own phones never load (or tap) a real ad.
  /// Before the first release with it: Play Console (contains ads, advertising ID, Data safety) and the manifest's
  /// AD_ID lines (design doc, "Left before ads reach production").
  static const _unit = 'ca-app-pub-1300180769466949/9206368100';

  static String get unitId => kReleaseMode ? _unit : _testUnit;

  /// True once consent allows ad requests and the SDK has started.
  static final ready = ValueNotifier(false);

  /// Ask for consent where the law needs it (Google's UMP message, set up in AdMob > Privacy & messaging), then start
  /// the SDK. No ad is requested before this ends; a failure leaves ads off for this run.
  static Future<void> start() async {
    if (!Platform.isAndroid || unitId.isEmpty) return log('ads: off here');
    try {
      final asked = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => ConsentForm.loadAndShowConsentFormIfRequired(
          (_) => asked.complete(),
        ),
        (e) {
          log('ads: consent check failed (${e.message})');
          asked.complete();
        },
      );
      await asked.future;
      if (!await ConsentInformation.instance.canRequestAds()) {
        return log('ads: consent does not allow ad requests');
      }
      await MobileAds.instance.initialize();
      ready.value = true;
      log('ads: ready ($unitId)');
    } catch (e) {
      log('ads: not started ($e)');
    }
  }
}

/// Where the ads go among [cards] real cards: after the 6th, then after every 12 more (indexes in the real list, each
/// ad shown after that card). Fewer than 6 cards = none: an empty or short feed is not an ad slot.
List<int> adSlots(int cards) => [for (var at = 6; at <= cards; at += 12) at];

/// [cards] with an ad after each of [adSlots], [ad] given the slot's number (0, 1, ...); [skip] = slots whose ad
/// failed to load, left out so the grid closes up.
List<T> withAds<T>(
  List<T> cards,
  T Function(int slot) ad, {
  Set<int> skip = const {},
}) {
  final slots = adSlots(cards.length);
  return [
    for (final (i, card) in cards.indexed) ...[
      card,
      if (slots.indexOf(i + 1) case final s when s >= 0 && !skip.contains(s))
        ad(s),
    ],
  ];
}
