import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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

Future<String?> _askLink(BuildContext context) {
  final l = AppLocalizations.of(context);
  final field = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.addLink),
      content: TextField(
        key: const ValueKey('add-link-field'),
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: l.linkFieldLabel,
          helperText: l.addLinkHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, field.text.trim()),
          child: Text(l.linkAdd),
        ),
      ],
    ),
  ).whenComplete(field.dispose);
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
