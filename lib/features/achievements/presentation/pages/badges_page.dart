import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../data/achievements_api.dart';
import '../../domain/achievement.dart';
import '../widgets/achievement_badge.dart';

/// Account > Badges: one card per category (the tier reached, or bronze greyed), progress to the next tier; a tap
/// shows all five tiers. A tier reached on this read pops the "New badge" sheet. Private: the caller's own.
class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key, this.api});

  /// Tests pass a fake; the app builds one from the shared Dio.
  final AchievementsApi? api;

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  late final AchievementsApi _api =
      widget.api ?? AchievementsApi(context.read<ApiClient>().dio);
  late Future<List<Achievement>> _badges = _load();

  Future<List<Achievement>> _load() async {
    final list = await apiCall(_api.list);
    final fresh = [
      for (final a in list)
        if (a.fresh) a,
    ];
    if (fresh.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showNewBadges(context, fresh);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.badgesTitle)),
      body: NotebookPage(
        child: FutureBuilder(
          future: _badges,
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Text(errorText(l, s.error!)));
            }
            final list = s.data;
            if (list == null) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            final earned = list.fold(0, (n, a) => n + a.tier);
            final total = list.length * AchievementTier.values.length;
            return RefreshIndicator(
              onRefresh: () async {
                final next = _load();
                setState(() {
                  _badges = next;
                });
                await next;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  notebookGutter + 4,
                  8,
                  16,
                  24,
                ),
                children: [
                  Text(
                    l.badgesEarned(earned, total),
                    key: const ValueKey('badges-earned'),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.badgesHelp,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                    children: [
                      for (final a in list)
                        _BadgeCard(
                          key: ValueKey('badge-${a.category.name}'),
                          badge: a,
                          onTap: () => showNotebookSheet<void>(
                            context,
                            builder: (_) => _TiersSheet(badge: a),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String categoryName(AppLocalizations l, AchievementCategory c) => switch (c) {
  AchievementCategory.explorer => l.badgeExplorer,
  AchievementCategory.traveller => l.badgeTraveller,
  AchievementCategory.regular => l.badgeRegular,
  AchievementCategory.cook => l.badgeCook,
  AchievementCategory.critic => l.badgeCritic,
  AchievementCategory.helper => l.badgeHelper,
};

String _how(AppLocalizations l, AchievementCategory c) => switch (c) {
  AchievementCategory.explorer => l.badgeExplorerHow,
  AchievementCategory.traveller => l.badgeTravellerHow,
  AchievementCategory.regular => l.badgeRegularHow,
  AchievementCategory.cook => l.badgeCookHow,
  AchievementCategory.critic => l.badgeCriticHow,
  AchievementCategory.helper => l.badgeHelperHow,
};

String tierName(AppLocalizations l, AchievementTier t) => switch (t) {
  AchievementTier.bronze => l.tierBronze,
  AchievementTier.silver => l.tierSilver,
  AchievementTier.gold => l.tierGold,
  AchievementTier.platinum => l.tierPlatinum,
  AchievementTier.diamond => l.tierDiamond,
};

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({super.key, required this.badge, required this.onTap});

  final Achievement badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final a = badge;
    final name = categoryName(l, a.category);
    return Material(
      color: nb.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: nb.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            children: [
              Expanded(
                child: AchievementBadge(
                  category: a.category,
                  tier: a.shown,
                  locked: !a.earned,
                  size: 96,
                  label: a.earned
                      ? '$name, ${tierName(l, a.shown)}'
                      : '$name, ${l.badgeNone}',
                ),
              ),
              Text(
                name,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                a.earned ? tierName(l, a.shown) : l.badgeNone,
                style: text.bodySmall?.copyWith(
                  color: a.earned ? nb.pandan : nb.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: a.progress,
                  minHeight: 6,
                  backgroundColor: nb.line,
                  color: nb.pandan,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                a.next == null ? l.badgeTop : l.badgeProgress(a.count, a.next!),
                style: text.labelSmall?.copyWith(
                  color: nb.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// All five tiers of one category: earned in colour, the rest greyed, each with the count it needs.
class _TiersSheet extends StatelessWidget {
  const _TiersSheet({required this.badge});

  final Achievement badge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final a = badge;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            categoryName(l, a.category),
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _how(l, a.category),
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(
            l.badgeYourCount(a.count),
            textAlign: TextAlign.center,
            style: text.labelLarge?.copyWith(color: nb.pandan),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final t in AchievementTier.values)
                Expanded(
                  child: Column(
                    children: [
                      AchievementBadge(
                        key: ValueKey('tier-${t.name}'),
                        category: a.category,
                        tier: t,
                        locked: t.index >= a.tier,
                        size: 56,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tierName(l, t),
                        style: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (t.index < a.steps.length)
                        Text(
                          '${a.steps[t.index]}',
                          style: text.labelSmall?.copyWith(color: nb.inkSoft),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "New badge!": each tier reached on this read, the medal popping in.
Future<void> showNewBadges(
  BuildContext context,
  List<Achievement> fresh,
) => showNotebookSheet<void>(
  context,
  builder: (sheet) {
    final l = AppLocalizations.of(sheet);
    final text = Theme.of(sheet).textTheme;
    return Padding(
      key: const ValueKey('new-badges'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.badgeNew,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final a in fresh)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: AchievementBadge(
                        category: a.category,
                        tier: a.shown,
                        size: fresh.length == 1 ? 160 : 104,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${categoryName(l, a.category)} · ${tierName(l, a.shown)}',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('new-badges-ok'),
              onPressed: () => Navigator.pop(sheet),
              child: Text(l.badgeNice),
            ),
          ),
        ],
      ),
    );
  },
);
