import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// What Owner > Catalogue edits: the API path segment.
enum CatalogueKind { products, brands, makers }

/// Every page of a catalogue list, for a form's picker.
// shortcut: loads every row (121 makers, 194 brands today); a search-as-you-type picker past ~1000.
Future<List<T>> allPages<T>(
  Future<CataloguePage<T>> Function(int offset) page,
) async {
  final all = <T>[];
  int? offset = 0;
  while (offset != null) {
    final p = await page(offset);
    all.addAll(p.items);
    offset = p.next;
  }
  return all;
}

/// Add ([row] null) or edit one maker, brand or product, with Delete for an existing one. Pops 'saved' or 'deleted'.
class CatalogueEditSheet extends StatefulWidget {
  const CatalogueEditSheet({
    super.key,
    required this.kind,
    this.row,
    this.countries = const [],
    this.units = const [],
  });

  final CatalogueKind kind;

  /// A [CatalogueMaker], [CatalogueBrand] or [CatalogueProduct] of [kind]; null = new.
  final Object? row;
  final List<String> countries;
  final List<String> units;

  @override
  State<CatalogueEditSheet> createState() => _CatalogueEditSheetState();
}

class _CatalogueEditSheetState extends State<CatalogueEditSheet> {
  final _name = TextEditingController();
  final _maker = TextEditingController();
  final _country = TextEditingController();
  final _brand = TextEditingController();
  final _ingredient = TextEditingController();
  final _size = TextEditingController();
  final _unit = TextEditingController();
  List<CatalogueMaker> _makers = const [];
  List<CatalogueBrand> _brands = const [];
  List<String> _suggested = const [];
  Timer? _debounce;
  bool _busy = false;
  bool _taken = false;
  bool _unknown = false;

  OwnerRepository get _repo => context.read<OwnerRepository>();

  @override
  void initState() {
    super.initState();
    switch (widget.row) {
      case CatalogueMaker m:
        _name.text = m.name;
      case CatalogueBrand b:
        _name.text = b.name;
        _maker.text = b.maker ?? '';
        _country.text = b.country ?? '';
      case CatalogueProduct p:
        _name.text = p.name;
        _brand.text = p.brand ?? '';
        _ingredient.text = p.ingredient ?? '';
        _size.text = p.size == null
            ? ''
            : p.size! % 1 == 0
            ? p.size!.toInt().toString()
            : '${p.size}';
        _unit.text = p.unit ?? '';
    }
    _loadPickers();
  }

  Future<void> _loadPickers() async {
    try {
      if (widget.kind == CatalogueKind.brands) {
        final m = await allPages((o) => _repo.makers(offset: o));
        if (mounted) setState(() => _makers = m);
      } else if (widget.kind == CatalogueKind.products) {
        final b = await allPages(
          (o) async => (await _repo.brands(offset: o)).$1,
        );
        if (mounted) setState(() => _brands = b);
      }
    } catch (_) {
      // The picker stays empty; the field keeps its value and Save still works.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [
      _name,
      _maker,
      _country,
      _brand,
      _ingredient,
      _size,
      _unit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Catalogue ingredient names as the owner types (the server knows them by name).
  void _findIngredient(String q) {
    _debounce?.cancel();
    setState(() => _unknown = false);
    if (q.trim().length < 2) {
      setState(() => _suggested = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final found = await _repo
          .searchIngredients(q.trim())
          .catchError((_) => <String>[]);
      if (mounted) setState(() => _suggested = found.take(5).toList());
    });
  }

  String? _orNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty || t == AppLocalizations.of(context).catalogueNone
        ? null
        : t;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = switch (widget.row) {
      CatalogueMaker m => m.id,
      CatalogueBrand b => b.id,
      CatalogueProduct p => p.id,
      _ => null,
    };
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      switch (widget.kind) {
        case CatalogueKind.makers:
          await _repo.saveMaker(id: id, name: name);
        case CatalogueKind.brands:
          final maker = _orNull(_maker);
          await _repo.saveBrand(
            id: id,
            name: name,
            makerId: maker == null
                ? null
                : _makers.where((m) => m.name == maker).firstOrNull?.id ??
                      (widget.row as CatalogueBrand?)?.makerId,
            country: _orNull(_country),
          );
        case CatalogueKind.products:
          final brand = _orNull(_brand);
          await _repo.saveProduct(
            id: id,
            name: name,
            ingredient: _orNull(_ingredient),
            brandId: brand == null
                ? null
                : _brands.where((b) => b.name == brand).firstOrNull?.id ??
                      (widget.row as CatalogueProduct?)?.brandId,
            size: double.tryParse(_size.text.trim().replaceAll(',', '.')),
            unit: _orNull(_unit),
          );
      }
      if (mounted) Navigator.of(context).pop('saved');
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'name_taken':
          setState(() => _taken = true);
        case 'not_found':
          setState(() => _unknown = true);
        default:
          messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final (id, name) = switch (widget.row) {
      CatalogueMaker m => (m.id, m.name),
      CatalogueBrand b => (b.id, b.name),
      CatalogueProduct p => (p.id, p.name),
      _ => throw StateError('nothing to delete'),
    };
    final sure = await showBaseDialog(
      context,
      message: l.catalogueDeleteAsk(name),
      tone: DialogTone.danger,
      confirmLabel: l.delete,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteCatalogueRow(widget.kind.name, id);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    const gap = SizedBox(height: spaceS);
    final title = switch (widget.kind) {
      CatalogueKind.products => l.catalogueProducts,
      CatalogueKind.brands => l.catalogueBrands,
      CatalogueKind.makers => l.catalogueMakers,
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(spaceM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.row == null ? '${l.catalogueAdd}: $title' : title,
            style: text.titleMedium,
          ),
          gap,
          TextField(
            key: const ValueKey('catalogue-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l.catalogueName,
              errorText: _taken ? l.catalogueTaken : null,
            ),
            onChanged: (_) => setState(() => _taken = false),
          ),
          if (widget.kind == CatalogueKind.brands) ...[
            gap,
            PickerField(
              controller: _maker,
              label: l.catalogueMaker,
              options: [l.catalogueNone, for (final m in _makers) m.name],
            ),
            gap,
            PickerField(
              controller: _country,
              label: l.catalogueCountry,
              options: [l.catalogueNone, ...widget.countries],
              allowTyped: true,
            ),
          ],
          if (widget.kind == CatalogueKind.products) ...[
            gap,
            PickerField(
              controller: _brand,
              label: l.catalogueBrand,
              options: [l.catalogueNone, for (final b in _brands) b.name],
            ),
            gap,
            TextField(
              key: const ValueKey('catalogue-ingredient'),
              controller: _ingredient,
              decoration: InputDecoration(
                labelText: l.catalogueIngredient,
                errorText: _unknown ? l.catalogueUnknown : null,
                errorMaxLines: 3,
              ),
              onChanged: _findIngredient,
            ),
            if (_suggested.isNotEmpty)
              Wrap(
                spacing: spaceXs,
                children: [
                  for (final s in _suggested)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() {
                        _ingredient.text = s;
                        _suggested = const [];
                        _unknown = false;
                      }),
                    ),
                ],
              ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('catalogue-size'),
                    controller: _size,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(labelText: l.catalogueSize),
                  ),
                ),
                const SizedBox(width: spaceS),
                Expanded(
                  child: PickerField(
                    controller: _unit,
                    label: l.catalogueUnit,
                    options: [l.catalogueNone, ...widget.units],
                    allowTyped: true,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: spaceM),
          // Negative left, positive right (owner panels).
          Row(
            children: [
              if (widget.row != null)
                TextButton(
                  key: const ValueKey('catalogue-delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _busy ? null : _delete,
                  child: Text(l.delete),
                ),
              const Spacer(),
              ListenableBuilder(
                listenable: _name,
                builder: (_, _) => FilledButton(
                  key: const ValueKey('catalogue-save'),
                  onPressed: _busy || _name.text.trim().length < 2
                      ? null
                      : _save,
                  child: Text(l.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
