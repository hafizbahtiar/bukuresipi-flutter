import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme_constant.dart';
import '../../../core/widgets/base.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_text.dart';
import '../../receipts/domain/receipts_repository.dart';
import '../../receipts/presentation/pages/meal_page.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/pages/recipe_edit_page.dart';
import '../../shares/presentation/share_intake.dart';
import 'pages/home_page.dart';

/// The bottom bar's "+": every way to add something, in one sheet. Paste a link, Receipt and Meal go on to their next
/// step in that same sheet ([SheetSwitcher]), never a second one. A link and a screenshot go through the same intake
/// as the phone's share sheet; a receipt is uploaded and opened; a meal photo is estimated, and once saved the day's
/// calories show; a typed recipe opens the editor.
Future<void> showAddSheet(BuildContext context) async {
  final pick = await showBaseSheet<_Pick>(
    context,
    builder: (_) => const _AddSheet(),
  );
  if (pick == null || !context.mounted) return;
  switch (pick) {
    case (kind: 'link', value: final String link):
      context.read<ShareIntake>().add(Incoming.text(link));
    case (kind: 'screenshot', value: _):
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && context.mounted) {
        context.read<ShareIntake>().add(Incoming.image(image.path));
      }
    case (kind: 'receipt', value: final ImageSource source):
      await _addReceipt(context, source);
    case (kind: 'meal', value: final ImageSource source):
      await _addMeal(context, source);
    case (kind: 'recipe', value: _):
      final saved = await Navigator.of(context).push<RecipeDetail>(
        MaterialPageRoute(builder: (_) => const RecipeEditPage()),
      );
      if (saved != null && context.mounted) {
        unawaited(context.push('/recipes/${saved.id}'));
      }
  }
}

/// What the sheet closed with: the row, and its link or photo source.
typedef _Pick = ({String kind, Object? value});

/// The menu, then (in the same sheet) the link field or camera/photos. The sheet owns the link field, so it lives
/// until the sheet has finished closing.
class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  /// null = the menu; 'link', 'receipt' or 'meal' = that row's next step.
  String? _step;
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _close(String kind, [Object? value]) =>
      Navigator.pop<_Pick>(context, (kind: kind, value: value));

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text != null && text.isNotEmpty && mounted) {
      setState(() => _field.text = text);
    }
  }

  void _addLink() {
    final link = _field.text.trim();
    if (link.isNotEmpty) _close('link', link);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SheetSwitcher(
      child: switch (_step) {
        null => _menu(l),
        'link' => _link(l),
        final step => PhotoSourceTiles(
          key: ValueKey('add-step-$step'),
          camera: step == 'meal' ? l.mealSnap : l.receiptSnap,
          onPick: (source) => _close(step, source),
        ),
      },
    );
  }

  Widget _menu(AppLocalizations l) => ListView(
    key: const ValueKey('add-step-menu'),
    shrinkWrap: true, // as tall as its rows; scrolls on a small screen
    padding: EdgeInsets.zero,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: spaceXs),
        child: Center(
          child: Text(
            l.addTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      for (final (key, icon, title, hint, next) in [
        ('link', Icons.link, l.addLink, l.addLinkHint, true),
        (
          'screenshot',
          Icons.image_outlined,
          l.addScreenshot,
          l.addScreenshotHint,
          false,
        ),
        (
          'receipt',
          Icons.receipt_long_outlined,
          l.addReceipt,
          l.addReceiptHint,
          true,
        ),
        ('meal', Icons.restaurant_outlined, l.addMeal, l.addMealHint, true),
        ('recipe', Icons.edit_note, l.addRecipe, l.addRecipeHint, false),
      ])
        ListTile(
          key: ValueKey('add-$key'),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(hint),
          onTap: () => next ? setState(() => _step = key) : _close(key),
        ),
    ],
  );

  Widget _link(AppLocalizations l) {
    final material = MaterialLocalizations.of(context);
    return Padding(
      key: const ValueKey('add-step-link'),
      padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, 16),
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
            onSubmitted: (_) => _addLink(),
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
                  onPressed: _field.text.trim().isEmpty ? null : _addLink,
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

Future<void> _addReceipt(BuildContext context, ImageSource source) async {
  final l = AppLocalizations.of(context);
  final repo = context.read<ReceiptsRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final path = source == ImageSource.camera
      ? await _scan()
      : (await _pick(ImageSource.gallery))?.path;
  if (path == null) return;
  try {
    final id = await repo.upload(path);
    unawaited(router.push('/receipts/$id'));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
  }
}

/// The estimate page for the photo; a saved meal lands on the Calories side, reloaded.
Future<void> _addMeal(BuildContext context, ImageSource source) async {
  // 1600 px is plenty to tell dishes apart and keeps the upload small.
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return;
  final saved = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => MealPage(path: picked.path)));
  if (saved == true && context.mounted) {
    context.go('/', extra: HomePage.caloriesTab);
  }
}

// 2000 px keeps small print readable and the upload well under the 5 MB cap.
Future<XFile?> _pick(ImageSource source) => ImagePicker().pickImage(
  source: source,
  maxWidth: 2000,
  maxHeight: 2000,
  imageQuality: 88,
);

/// The phone's document scanner (Android, Google Play services): finds the receipt's edges, crops and
/// straightens it, so less background reaches the read. No scanner (iOS, no Play services) = the plain camera.
// shortcut: the scan is not downscaled (ML Kit's page JPEG is ~1-3 MB, under the 5 MB cap); resize if uploads fail.
Future<String?> _scan() async {
  final scanner = DocumentScanner(options: DocumentScannerOptions());
  try {
    final pages = (await scanner.scanDocument()).images;
    return pages == null || pages.isEmpty ? null : pages.first;
  } on PlatformException catch (e) {
    if (e.message == 'Operation cancelled') return null;
    return (await _pick(ImageSource.camera))?.path;
  } on MissingPluginException {
    return (await _pick(ImageSource.camera))?.path;
  } finally {
    unawaited(scanner.close().catchError((Object _) {}));
  }
}
