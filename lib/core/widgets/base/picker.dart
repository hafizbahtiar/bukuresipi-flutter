import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_constant.dart';
import 'sheets.dart';

/// Picks one of [options] in a bottom sheet, the current one ticked. null = dismissed without choosing.
/// [search] (on by default) adds a box that filters the list as you type; turn it off for a few fixed choices.
/// [custom] lets the typed text itself be the answer when it matches no option ("Use “Taman Melati”").
Future<T?> showBasePicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T) label,
  bool search = true,
  T Function(String typed)? custom,
}) {
  FocusScope.of(context).unfocus();
  // Floating, as every sheet: it keeps above the keyboard (search box) by itself.
  return showBaseSheet<T>(
    context,
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
      ),
      child: _PickerSheet<T>(
        title: title,
        options: options,
        selected: selected,
        label: label,
        search: search,
        custom: custom,
      ),
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.search,
    required this.custom,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final bool search;
  final T Function(String typed)? custom;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty || widget.label(o).toLowerCase().contains(q)) o,
    ];
    final exact = widget.options.any((o) => widget.label(o).toLowerCase() == q);
    final typed = _query.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.search)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
            child: TextField(
              key: const ValueKey('picker-search'),
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.pickerSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: spaceS),
            children: [
              if (widget.custom case final custom?
                  when typed.isNotEmpty && !exact)
                ListTile(
                  key: const ValueKey('picker-custom'),
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l.pickerUseTyped(typed)),
                  onTap: () => Navigator.pop(context, custom(typed)),
                ),
              for (final option in shown)
                ListTile(
                  title: Text(widget.label(option)),
                  selected: option == widget.selected,
                  trailing: option == widget.selected
                      ? Icon(Icons.check, color: nb.pandanDeep)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
              if (shown.isEmpty && widget.custom == null)
                ListTile(
                  title: Text(
                    l.pickerNone,
                    style: TextStyle(color: nb.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A form field whose value is picked from a list in a [showBasePicker] sheet: looks like a text field, opens the
/// sheet on tap. No [options] (e.g. offline) = a plain text field, so the value can still be typed.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.controller,
    required this.label,
    this.badge,
    required this.options,
    this.search = true,
    this.allowTyped = false,
    this.onPicked,
  });

  final TextEditingController controller;

  final String label;

  /// Beside the label, e.g. an AiBadge when AI filled the field.
  final Widget? badge;
  final List<String> options;
  final bool search;

  /// The typed text may be kept when it matches no option.
  final bool allowTyped;
  final ValueChanged<String>? onPicked;

  Future<void> _open(BuildContext context) async {
    final picked = await showBasePicker<String>(
      context,
      title: label,
      options: options,
      selected: controller.text.isEmpty ? null : controller.text,
      label: (o) => o,
      search: search,
      custom: allowTyped ? (typed) => typed : null,
    );
    if (picked == null) return;
    controller.text = picked;
    onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    readOnly: options.isNotEmpty,
    onTap: options.isEmpty ? null : () => _open(context),
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(
      label: badge == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                badge!,
              ],
            ),
      suffixIcon: options.isEmpty ? null : const Icon(Icons.arrow_drop_down),
    ),
  );
}
