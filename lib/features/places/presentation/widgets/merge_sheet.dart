import 'package:flutter/material.dart';

import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/place.dart';

/// Owner: which restaurant stays and its name (the words the picked names share, e.g. "Samurai Yakiniku" from
/// "Samurai Yakiniku Bangi" + "Samurai Yakiniku Setapak"). Pops `(into, name)`; name null = keep the kept one's.
class MergeSheet extends StatefulWidget {
  const MergeSheet({super.key, required this.places});

  final List<Place> places;

  @override
  State<MergeSheet> createState() => _MergeSheetState();
}

/// The words every name starts with, as written in the first; empty when none.
String sharedStart(List<String> names) {
  final words = [for (final n in names) n.trim().split(RegExp(r'\s+'))];
  final out = <String>[];
  for (var i = 0; i < words.first.length; i++) {
    final w = words.first[i];
    if (words.any(
      (ws) => ws.length <= i || ws[i].toLowerCase() != w.toLowerCase(),
    )) {
      break;
    }
    out.add(w);
  }
  return out.join(' ');
}

class _MergeSheetState extends State<MergeSheet> {
  late String _into = widget.places.first.restaurant.id;
  late final _name = TextEditingController(
    text: switch (sharedStart([
      for (final p in widget.places) p.restaurant.name,
    ])) {
      '' => widget.places.first.restaurant.name,
      final s => s,
    },
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final kept = widget.places.firstWhere((p) => p.restaurant.id == _into);
    final name = _name.text.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        notebookGutter + 10,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.mergeTitle,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(l.mergeHint, style: text.bodySmall),
          const SizedBox(height: 12),
          Text(l.mergeKeep, style: text.labelLarge),
          RadioGroup<String>(
            groupValue: _into,
            onChanged: (v) => setState(() => _into = v!),
            child: Column(
              children: [
                for (final p in widget.places)
                  RadioListTile<String>(
                    key: ValueKey('merge-into-${p.restaurant.id}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: p.restaurant.id,
                    title: Text(p.restaurant.name),
                  ),
              ],
            ),
          ),
          TextField(
            key: const ValueKey('merge-name'),
            controller: _name,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.mergeName),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(material.cancelButtonLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('merge-confirm'),
                  onPressed: name.isEmpty
                      ? null
                      : () => Navigator.pop(context, (
                          into: _into,
                          name: name == kept.restaurant.name ? null : name,
                        )),
                  child: Text(l.mergeAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
