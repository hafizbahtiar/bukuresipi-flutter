import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/ai_button.dart';
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
  final _fillFrom = TextEditingController();
  ProductFill? _fill;
  bool _filling = false;
  bool _brandAdded = false;
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

  /// A barcode or a store link fills the form (nothing saved); the owner checks it and saves.
  Future<void> _fillProduct() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final from = _fillFrom.text.trim();
    if (from.isEmpty) return;
    setState(() => _filling = true);
    try {
      // Digits = a barcode; a link = its page; anything else = a product name to search for.
      final barcode = RegExp(r'^\d{8,14}$').hasMatch(from);
      final link = from.startsWith(RegExp('https?://'));
      final f = await _repo.fillProduct(
        barcode: barcode ? from : null,
        url: link ? from : null,
        name: barcode || link ? null : from,
      );
      if (!mounted) return;
      setState(() {
        _fill = f;
        _brandAdded = false;
        _name.text = f.name;
        _brand.text = f.brandIsNew ? '' : (f.brand ?? '');
        _ingredient.text = f.ingredient ?? '';
        _size.text = f.size == null
            ? ''
            : f.size! % 1 == 0
            ? f.size!.toInt().toString()
            : '${f.size}';
        _unit.text = f.unit ?? '';
        _taken = false;
        _unknown = false;
      });
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.code) {
            'not_found' => l.catalogueFillNotFound,
            'unreadable' => l.catalogueFillUnreadable,
            _ => errorText(l, e),
          }),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  /// The filled product's brand is new: add it (with the maker and country a page named, else by its name only:
  /// they are filled in Brands), then pick it.
  Future<void> _addBrand(String name) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final maker = _fill?.maker;
    setState(() => _busy = true);
    try {
      int? makerId;
      if (maker != null) {
        Future<int?> find() async =>
            (await _repo.makers(query: maker.name)).items
                .where((m) => m.name.toLowerCase() == maker.name.toLowerCase())
                .firstOrNull
                ?.id;
        makerId = await find();
        if (makerId == null) {
          await _repo.saveMaker(name: maker.name);
          makerId = await find();
        }
      }
      await _repo.saveBrand(
        name: name,
        makerId: makerId,
        country: maker?.country,
      );
    } on ApiException catch (e) {
      // Added meanwhile: pick it all the same.
      if (e.code != 'name_taken') {
        messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    await _loadPickers();
    if (!mounted) return;
    setState(() {
      _brandAdded = true;
      _brand.text = name;
      _busy = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fillFrom.dispose();
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
          if (widget.kind == CatalogueKind.products && widget.row == null) ...[
            gap,
            TextField(
              key: const ValueKey('catalogue-fill'),
              controller: _fillFrom,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.catalogueFillFrom,
                helperText: _fill == null
                    ? l.catalogueFillHint
                    : l.catalogueFillSource(
                        Uri.tryParse(_fill!.source)?.host ?? _fill!.source,
                      ),
                helperMaxLines: 2,
              ),
              onSubmitted: (_) => _fillProduct(),
            ),
            const SizedBox(height: spaceXs),
            Align(
              alignment: Alignment.centerRight,
              child: AiButton(
                key: const ValueKey('catalogue-fill-go'),
                label: l.catalogueFill,
                busy: _filling,
                onPressed: _fillProduct,
              ),
            ),
          ],
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
            if (_fill case final f? when f.brandIsNew && !_brandAdded) ...[
              gap,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.catalogueNewBrand(f.brand!)),
                        if (f.maker case final m?)
                          Text(
                            l.catalogueMadeBy(
                              m.country == null
                                  ? m.name
                                  : '${m.name}, ${m.country}',
                              Uri.tryParse(m.source)?.host ?? m.source,
                            ),
                            style: text.bodySmall?.copyWith(
                              color: Notebook.of(context).inkSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('catalogue-add-brand'),
                    onPressed: _busy ? null : () => _addBrand(f.brand!),
                    child: Text(l.catalogueAddBrand),
                  ),
                ],
              ),
            ],
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
                // The AI named it; the owner can still change it.
                suffixIcon:
                    _fill?.aiIngredient == true &&
                        _ingredient.text == _fill!.ingredient
                    ? const Padding(
                        padding: EdgeInsets.all(spaceS),
                        child: AiBadge(),
                      )
                    : null,
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
