import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../widgets/ai_setting_sheet.dart';

/// Owner > AI: the default model and thinking level, then each use with its own or "Default" (tap to change).
class OwnerAiPage extends StatefulWidget {
  const OwnerAiPage({super.key});

  @override
  State<OwnerAiPage> createState() => _OwnerAiPageState();
}

class _OwnerAiPageState extends State<OwnerAiPage> {
  AiSettings? _ai;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ai = await context.read<OwnerRepository>().aiSettings();
      if (mounted) {
        setState(() {
          _ai = ai;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _line(AppLocalizations l, AiSettings ai, AiSetting s) {
    var model = s.model;
    for (final p in ai.providers) {
      for (final m in p.models) {
        if (p.id == s.provider && m.id == s.model) model = m.name;
      }
    }
    return '$model · ${aiLevelLabel(l, s.reasoning)}';
  }

  static String _useLabel(AppLocalizations l, String id) => switch (id) {
    'share_extract' => l.aiUseShareExtract,
    'image_read' => l.aiUseImageRead,
    'branch_extract' => l.aiUseBranchExtract,
    'recipe_extract' => l.aiUseRecipeExtract,
    'geo_query' => l.aiUseGeoQuery,
    'place_draft' => l.aiUsePlaceDraft,
    'dish_draft' => l.aiUseDishDraft,
    'ingredient_name' => l.aiUseIngredientName,
    'brand_maker' => l.aiUseBrandMaker,
    'ingredient_aliases' => l.aiUseIngredientAliases,
    'receipt_read' => l.aiUseReceiptRead,
    'dish_match' => l.aiUseDishMatch,
    'meal_read' => l.aiUseMealRead,
    'cover_pick' => l.aiUseCoverPick,
    'pantry_suggest' => l.aiUsePantrySuggest,
    _ => id, // a use newer than this app
  };

  Future<void> _edit(AiSettings ai, String title, AiUse? use) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<OwnerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showAiSettingSheet(
      context,
      title: title,
      settings: ai,
      current: use?.setting ?? ai.defaults,
      use: use,
    );
    if (choice == null) return;
    final id = use?.id ?? 'default';
    try {
      final updated = switch (choice.setting) {
        final s? => await repo.saveAiSetting(id, s),
        null => await repo.clearAiSetting(id),
      };
      if (mounted) setState(() => _ai = updated);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final ai = _ai;
    Widget row(String title, String line, VoidCallback onTap, {Key? key}) =>
        NotebookRow(
          key: key,
          onTap: onTap,
          trailing: const Icon(Icons.chevron_right),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              Text(line, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.ownerAi)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: ai == null
            ? null
            : NotebookPage(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    NotebookRow(
                      child: Text(
                        l.ownerAiHelp,
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                    ),
                    row(
                      l.aiDefault,
                      _line(l, ai, ai.defaults),
                      () => _edit(ai, l.aiDefault, null),
                      key: const ValueKey('ai-default'),
                    ),
                    NotebookHeading(l.aiUses),
                    for (final u in ai.uses)
                      row(
                        _useLabel(l, u.id),
                        switch (u.setting) {
                          final s? => _line(l, ai, s),
                          null => l.aiDefault,
                        },
                        () => _edit(ai, _useLabel(l, u.id), u),
                        key: ValueKey('ai-use-${u.id}'),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
