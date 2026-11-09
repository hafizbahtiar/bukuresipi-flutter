import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/notebook.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_text.dart';
import '../../receipts/domain/receipts_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/pages/recipe_edit_page.dart';
import '../../shares/presentation/share_intake.dart';

/// The bottom bar's "+": every way to add something, in one sheet. A link and a screenshot go through the same
/// intake as the phone's share sheet; a receipt is uploaded and opened; a typed recipe opens the editor.
Future<void> showAddSheet(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true, // as tall as its rows; scrolls on a small screen
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Text(
              l.addTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final (key, icon, title, hint) in [
            ('link', Icons.link, l.addLink, l.addLinkHint),
            (
              'screenshot',
              Icons.image_outlined,
              l.addScreenshot,
              l.addScreenshotHint,
            ),
            (
              'receipt',
              Icons.receipt_long_outlined,
              l.addReceipt,
              l.addReceiptHint,
            ),
            ('recipe', Icons.edit_note, l.addRecipe, l.addRecipeHint),
          ])
            ListTile(
              key: ValueKey('add-$key'),
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(hint),
              onTap: () => Navigator.pop(context, key),
            ),
        ],
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  switch (pick) {
    case 'link':
      final link = await _askLink(context);
      if (link != null && context.mounted) {
        context.read<ShareIntake>().add(Incoming.text(link));
      }
    case 'screenshot':
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && context.mounted) {
        context.read<ShareIntake>().add(Incoming.image(image.path));
      }
    case 'receipt':
      await _addReceipt(context);
    case 'recipe':
      final saved = await Navigator.of(context).push<RecipeDetail>(
        MaterialPageRoute(builder: (_) => const RecipeEditPage()),
      );
      if (saved != null && context.mounted) {
        unawaited(context.push('/recipes/${saved.id}'));
      }
  }
}

Future<String?> _askLink(BuildContext context) =>
    showNotebookSheet<String>(context, builder: (_) => const _LinkSheet());

/// One link to add. The sheet owns its field, so the field lives until the sheet has finished closing.
class _LinkSheet extends StatefulWidget {
  const _LinkSheet();

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text != null && text.isNotEmpty && mounted) {
      setState(() => _field.text = text);
    }
  }

  void _add() {
    final link = _field.text.trim();
    if (link.isNotEmpty) Navigator.pop(context, link);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
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
            l.addLink,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('add-link-field'),
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              labelText: l.linkFieldLabel,
              helperText: l.addLinkHint,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: TextButton.icon(
                key: const ValueKey('add-link-paste'),
                onPressed: _paste,
                icon: const Icon(Icons.content_paste, size: 18),
                label: Text(material.pasteButtonLabel),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                  key: const ValueKey('add-link-submit'),
                  onPressed: _field.text.trim().isEmpty ? null : _add,
                  child: Text(l.linkAdd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _addReceipt(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l.receiptSnap),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l.receiptFromGallery),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  final repo = context.read<ReceiptsRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  // 2000 px keeps small print readable and the upload well under the 5 MB cap.
  final photo = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 88,
  );
  if (photo == null) return;
  try {
    final id = await repo.upload(photo.path);
    unawaited(router.push('/receipts/$id'));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
  }
}
