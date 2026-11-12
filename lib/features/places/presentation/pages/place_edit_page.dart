import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../widgets/place_category.dart';

/// Owner: edit mode of the main place (shared by every user): its name, category + type and (food only) cuisine. Halal is not here: it stays
/// a quoted claim. Branches have their own page.
class PlaceEditPage extends StatefulWidget {
  const PlaceEditPage({super.key, required this.restaurant});

  final PlaceRestaurant restaurant;

  static Future<void> open(BuildContext context, PlaceRestaurant r) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlaceEditPage(restaurant: r)),
      );

  @override
  State<PlaceEditPage> createState() => _PlaceEditPageState();
}

class _PlaceEditPageState extends State<PlaceEditPage> {
  late final _name = TextEditingController(text: widget.restaurant.name);
  late final _cuisine = TextEditingController(
    text: widget.restaurant.cuisine ?? '',
  );
  late String _category = widget.restaurant.category;
  late String? _subcategory = widget.restaurant.subcategory;
  bool _saving = false;
  bool _tried = false;

  Future<void> _pickCategory() async {
    final l = AppLocalizations.of(context);
    final picked = await showBasePicker<String>(
      context,
      title: l.placeCategory,
      options: PlaceRestaurant.categories.keys.toList(),
      selected: _category,
      label: (c) => placeCategoryLabel(l, c),
      search: false,
    );
    // Another category: the old type belongs to the old one.
    if (picked != null && picked != _category) {
      setState(() {
        _category = picked;
        _subcategory = null;
      });
    }
  }

  Future<void> _pickSubcategory() async {
    final l = AppLocalizations.of(context);
    final picked = await showBasePicker<String>(
      context,
      title: l.placeSubcategory,
      // '' = not set.
      options: ['', ...?PlaceRestaurant.categories[_category]],
      selected: _subcategory ?? '',
      label: (s) => placeSubcategoryLabel(l, s),
      search: false,
    );
    if (picked != null) {
      setState(() => _subcategory = picked.isEmpty ? null : picked);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _cuisine.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _tried = true);
      return;
    }
    final cuisine = _cuisine.text.trim();
    setState(() => _saving = true);
    try {
      await context.read<PlacesController>().updateRestaurant(
        widget.restaurant.id,
        name: name,
        category: _category,
        subcategory: _subcategory,
        // Cuisine is for food: another category clears it.
        cuisine: cuisine.isEmpty || !_food ? null : cuisine,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.placeSaved)));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _food =>
      PlaceRestaurant(id: '', name: '', category: _category).isFood;

  /// A read-only field that opens a picker (no typing a value the server does not know).
  Widget _pickerField({
    required Key key,
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) => InkWell(
    key: key,
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(value),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.placeEdit),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(spaceM),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  key: const ValueKey('place-save'),
                  tooltip: l.save,
                  icon: const Icon(Icons.check),
                  onPressed: _save,
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(spaceM),
        children: [
          InfoCard(text: l.placeEditShared, icon: Icons.groups_outlined),
          const SizedBox(height: spaceM),
          TextField(
            key: const ValueKey('place-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 120,
            onChanged: (_) {
              if (_tried) setState(() {});
            },
            decoration: InputDecoration(
              labelText: l.placeName,
              errorText: _tried && _name.text.trim().isEmpty
                  ? l.placeNameRequired
                  : null,
            ),
          ),
          const SizedBox(height: spaceS),
          _pickerField(
            key: const ValueKey('place-category'),
            label: l.placeCategory,
            icon: placeCategoryIcon(_category),
            value: placeCategoryLabel(l, _category),
            onTap: _pickCategory,
          ),
          if (PlaceRestaurant.categories[_category]?.isNotEmpty ?? false) ...[
            const SizedBox(height: spaceM),
            _pickerField(
              key: const ValueKey('place-subcategory'),
              label: l.placeSubcategory,
              icon: placeCategoryIcon(_category, _subcategory),
              value: placeSubcategoryLabel(l, _subcategory ?? ''),
              onTap: _pickSubcategory,
            ),
          ],
          const SizedBox(height: spaceM),
          if (_food)
            TextField(
              key: const ValueKey('place-cuisine'),
              controller: _cuisine,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLength: 100,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(labelText: l.placeCuisine),
            ),
        ],
      ),
    );
  }
}
