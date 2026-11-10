import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A pill track of options, the chosen one a raised chip: Settings' language and theme, a recipe's tabs.
/// Each option is (value, what it shows, tooltip + screen-reader name or null when what it shows is text).
class PillSwitch<T> extends StatelessWidget {
  const PillSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.options,
    this.expand = false,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, Widget, String?)> options;

  /// true = the segments share the full width (tabs); false = as narrow as their content (a row's trailing).
  final bool expand;

  Widget _segment(Widget child) => expand ? Expanded(child: child) : child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    // One pill track; the chosen option is a raised chip in pandan. Dark paper is darker than mist, so the chip
    // takes the lighter line colour there (else it looks sunk in).
    final chip = Theme.of(context).brightness == Brightness.dark
        ? nb.line
        : nb.paper;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: nb.mist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: nb.line),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final (code, shown, name) in options)
            _segment(
              Semantics(
                button: true,
                selected: code == value,
                label: name,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(code),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 32,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: code == value ? chip : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: code == value
                          ? [
                              BoxShadow(
                                color: nb.ink.withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        size: 18,
                        color: code == value ? nb.pandanDeep : nb.inkSoft,
                      ),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: code == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: code == value ? nb.pandanDeep : nb.inkSoft,
                        ),
                        child: name == null
                            ? shown
                            : Tooltip(
                                message: name,
                                child: ExcludeSemantics(child: shown),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
