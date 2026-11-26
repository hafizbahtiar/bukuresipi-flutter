import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/owner.dart';

/// The owner's choice for one use (or the default): `null` = cancelled; `setting: null` = Use default.
typedef AiChoice = ({AiSetting? setting});

/// Pick a model and a thinking level for [title]. [use] null = the default. A text-only model is hidden for a use
/// that sends photos; as the default the server refuses it while an image use has no row (`ai_no_images`).
/// Use default shows only when [use] has its own row.
Future<AiChoice?> showAiSettingSheet(
  BuildContext context, {
  required String title,
  required AiSettings settings,
  required AiSetting current,
  AiUse? use,
}) => showBaseSheet<AiChoice>(
  context,
  builder: (_) => AiSettingSheet(
    title: title,
    settings: settings,
    current: current,
    use: use,
  ),
);

String aiLevelLabel(AppLocalizations l, String level) => switch (level) {
  'off' => l.aiReasoningOff,
  'low' => l.aiReasoningLow,
  'medium' => l.aiReasoningMedium,
  'high' => l.aiReasoningHigh,
  'max' => l.aiReasoningMax,
  _ => level,
};

class AiSettingSheet extends StatefulWidget {
  const AiSettingSheet({
    super.key,
    required this.title,
    required this.settings,
    required this.current,
    this.use,
  });

  final String title;
  final AiSettings settings;
  final AiSetting current;
  final AiUse? use;

  @override
  State<AiSettingSheet> createState() => _AiSettingSheetState();
}

class _AiSettingSheetState extends State<AiSettingSheet> {
  late AiSetting _pick = widget.current;

  AiModel? get _model {
    for (final p in widget.settings.providers) {
      for (final m in p.models) {
        if (p.id == _pick.provider && m.id == _pick.model) return m;
      }
    }
    return null;
  }

  bool get _needsImages => widget.use?.images ?? false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: nb.inkSoft);
    final model = _model;
    Widget check(bool on) =>
        Icon(on ? Icons.check : null, size: 20, color: nb.pandanDeep);
    Widget label(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, spaceXs),
      child: Text(s, style: text.labelLarge?.copyWith(color: nb.inkSoft)),
    );
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: spaceM),
      children: [
        NotebookRow(
          child: Text(
            widget.title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        label(l.aiModel),
        for (final p in widget.settings.providers)
          if (!p.configured)
            NotebookRow(
              child: Text('${p.name} · ${l.aiNotConfigured}', style: small),
            )
          else
            for (final m in p.models)
              if (m.images || !_needsImages)
                NotebookRow(
                  key: ValueKey('ai-model-${m.id}'),
                  mark: check(p.id == _pick.provider && m.id == _pick.model),
                  onTap: () => setState(
                    () => _pick = (
                      provider: p.id,
                      model: m.id,
                      reasoning: m.reasoning.contains(_pick.reasoning)
                          ? _pick.reasoning
                          : m.reasoning.first,
                    ),
                  ),
                  child: Text(m.name),
                ),
        if (model != null) ...[
          label(l.aiReasoning),
          for (final level in model.reasoning)
            NotebookRow(
              key: ValueKey('ai-level-$level'),
              mark: check(level == _pick.reasoning),
              onTap: () => setState(
                () => _pick = (
                  provider: _pick.provider,
                  model: _pick.model,
                  reasoning: level,
                ),
              ),
              child: Text(aiLevelLabel(l, level)),
            ),
          if ((widget.use?.budget ?? false) && _pick.reasoning != 'off')
            NotebookRow(
              mark: Icon(Icons.timer_outlined, size: 20, color: nb.margin),
              child: Text(l.aiBudgetWarning, style: small),
            ),
        ],
        if (widget.use?.setting != null)
          NotebookRow(
            key: const ValueKey('ai-use-default'),
            mark: Icon(Icons.undo, size: 20, color: nb.inkSoft),
            onTap: () => Navigator.of(context).pop((setting: null)),
            child: Text(l.aiUseDefault),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, 0),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: spaceM),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('ai-save'),
                  onPressed: model == null
                      ? null
                      : () => Navigator.of(context).pop((setting: _pick)),
                  child: Text(l.save),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
