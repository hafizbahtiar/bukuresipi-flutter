import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/notebook_dialog.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_text.dart';

/// One line of text in the notebook dialog; null = cancelled or left empty.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String message,
  String initial = '',
  String? hint,
  String? helper,
  String? confirmLabel,
  int maxLength = 40,
}) async {
  final l = AppLocalizations.of(context);
  var text = initial;
  final ok = await showNotebookDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel ?? l.save,
    content: _AskField(
      initial: initial,
      onChanged: (v) => text = v,
      maxLength: maxLength,
      hint: hint,
      helper: helper,
    ),
  );
  text = text.trim();
  return ok && text.isNotEmpty ? text : null;
}

/// Owns its controller: the dialog still rebuilds the field during its closing animation, after askText has its
/// answer, so the controller must live until the field itself goes (disposing it in askText crashed there).
class _AskField extends StatefulWidget {
  const _AskField({
    required this.initial,
    required this.onChanged,
    required this.maxLength,
    this.hint,
    this.helper,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final int maxLength;
  final String? hint;
  final String? helper;

  @override
  State<_AskField> createState() => _AskFieldState();
}

class _AskFieldState extends State<_AskField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    autofocus: true,
    maxLength: widget.maxLength,
    textCapitalization: TextCapitalization.words,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      hintText: widget.hint,
      helperText: widget.helper,
      helperMaxLines: 3,
    ),
  );
}

/// The server's rule for a name others see: 1-40 characters with a letter.
bool validName(String name) =>
    name.isNotEmpty &&
    name.length <= 40 &&
    RegExp(r'\p{L}', unicode: true).hasMatch(name);

/// Asks for the display name and saves it; true = saved.
Future<bool> askName(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final auth = context.read<AuthController>();
  final messenger = ScaffoldMessenger.of(context);
  final name = await askText(
    context,
    title: l.nameTitle,
    message: l.nameAsk,
    initial: auth.user?.name ?? '',
    helper: l.nameRule,
  );
  if (name == null) return false;
  if (!validName(name)) {
    messenger.showSnackBar(SnackBar(content: Text(l.errName)));
    return false;
  }
  try {
    await auth.setName(name);
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    return false;
  }
}

/// Runs [action]; when the server answers name_required (a family, a public recipe), asks for the name once and
/// runs it again. Other errors are thrown to the caller. false = the user did not give a name.
Future<bool> withName(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    if (e.code != 'name_required' || !context.mounted) rethrow;
    if (!await askName(context)) return false;
    await action();
    return true;
  }
}
