import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/utils/live_scanner.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/catalogue_photo.dart';
import '../../../../core/widgets/photo_editor_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../../../places/presentation/widgets/owner_panel.dart';

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
    this.initialName,
    this.initialIngredient,
    this.onSaved,
    this.pick,
  });

  /// Picks and crops a product photo (tests pass a fake); null = [pickPhoto]. A local JPEG path, null = backed out.
  final Future<String?> Function(BuildContext, ImageSource)? pick;

  /// A new row's name (and a product's ingredient and fill), e.g. from a recipe author's suggestion.
  final String? initialName;
  final String? initialIngredient;

  /// The name as saved, just before the sheet closes with 'saved'.
  final void Function(String name)? onSaved;

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

  /// The row being edited: [CatalogueEditSheet.row], or a product a fill found already in the catalogue.
  late Object? _row = widget.row;
  Timer? _debounce;
  bool _busy = false;
  bool _deleting = false; // which button spins while busy
  bool _taken = false;
  bool _unknown = false;

  // A product's photo: the saved one ([CatalogueProduct.photo]) unless replaced by a local pick or a fill's link,
  // or removed. Sent after the product is saved (a new one needs its id first).
  String? _photoPath;
  String? _photoUrl;
  bool _photoRemoved = false;

  // Read once (while mounted): a save goes on after the sheet is closed.
  late final OwnerRepository _repo = context.read<OwnerRepository>();

  @override
  void initState() {
    super.initState();
    _show(widget.row);
    if (widget.row == null) {
      _name.text = widget.initialName ?? '';
      _fillFrom.text = widget.initialName ?? '';
      _ingredient.text = widget.initialIngredient ?? '';
    }
    _loadPickers();
    // "New brand: X. Added when you save." shows only while no brand is picked.
    _brand.addListener(() => setState(() {}));
  }

  static String _sizeText(double? size) => size == null
      ? ''
      : size % 1 == 0
      ? size.toInt().toString()
      : '$size';

  /// [row]'s values in the fields.
  void _show(Object? row) {
    switch (row) {
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
        _size.text = _sizeText(p.size);
        _unit.text = p.unit ?? '';
    }
  }

  /// A fill found this product already: edit it in this sheet instead of adding it again.
  void _editInstead(CatalogueProduct p) => setState(() {
    _row = p;
    _fill = null;
    _photoUrl = null;
    _fillFrom.clear();
    _taken = false;
    _unknown = false;
    _show(p);
  });

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

  /// A product's barcode from the live scanner, then the fill as if typed.
  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final String? code;
    try {
      code = await scanCodeLive(product: true);
    } on Exception {
      messenger.showSnackBar(
        SnackBar(content: Text(l.catalogueScanUnavailable)),
      );
      return;
    }
    if (code == null || !mounted) return;
    _fillFrom.text = code;
    await _fillProduct();
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
      // A new product takes everything; an existing one only fills what is still empty.
      final editing = _row != null;
      void put(TextEditingController c, String v) {
        if (!editing || c.text.trim().isEmpty) c.text = v;
      }

      setState(() {
        _fill = f;
        _brandAdded = false;
        put(_name, f.name);
        put(_brand, f.brandIsNew ? '' : (f.brand ?? ''));
        put(_ingredient, f.ingredient ?? '');
        if (!editing ||
            (_size.text.trim().isEmpty && _unit.text.trim().isEmpty)) {
          _size.text = _sizeText(f.size);
          _unit.text = f.unit ?? '';
        }
        // Its photo, unless the product has one (or one was picked): the owner can still remove it.
        if (f.photo != null &&
            _photoPath == null &&
            (_savedPhoto == null || _photoRemoved)) {
          _photoUrl = f.photo;
          _photoRemoved = false;
        }
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

  /// Save of a fill whose brand is new and no brand picked: the brand first (with the maker and country a page
  /// named, else by its name only: they are filled in Brands), then picked. A name taken meanwhile is picked.
  Future<void> _addNewBrand(String name) async {
    final maker = _fill?.maker;
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
      if (e.code != 'name_taken') rethrow;
    }
    await _loadPickers();
    _brandAdded = true;
    _brand.text = name;
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
    final id = switch (_row) {
      CatalogueMaker m => m.id,
      CatalogueBrand b => b.id,
      CatalogueProduct p => p.id,
      _ => null,
    };
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      var photoSaved = true;
      switch (widget.kind) {
        case CatalogueKind.makers:
          await _repo.saveMaker(id: id, name: name);
        case CatalogueKind.brands:
          final maker = _orNull(_maker);
          final saved = await _repo.saveBrand(
            id: id,
            name: name,
            makerId: maker == null
                ? null
                : _makers.where((m) => m.name == maker).firstOrNull?.id ??
                      (_row as CatalogueBrand?)?.makerId,
            country: _orNull(_country),
          );
          photoSaved = await _savePhoto('brands', saved);
        case CatalogueKind.products:
          if (_fill case final f?
              when f.brandIsNew && !_brandAdded && _orNull(_brand) == null) {
            await _addNewBrand(f.brand!);
          }
          final brand = _orNull(_brand);
          final saved = await _repo.saveProduct(
            id: id,
            name: name,
            ingredient: _orNull(_ingredient),
            brandId: brand == null
                ? null
                : _brands.where((b) => b.name == brand).firstOrNull?.id ??
                      (_row as CatalogueProduct?)?.brandId,
            size: double.tryParse(_size.text.trim().replaceAll(',', '.')),
            unit: _orNull(_unit),
          );
          photoSaved = await _savePhoto('products', saved);
      }
      if (!photoSaved) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.catalogueSavedNoPhoto)),
        );
      }
      widget.onSaved?.call(name);
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
      if (mounted) setState(() => _busy = _deleting = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final (id, name) = switch (_row) {
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
    setState(() => _busy = _deleting = true);
    try {
      await _repo.deleteCatalogueRow(widget.kind.name, id);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? get _savedPhoto => switch (_row) {
    CatalogueProduct p => p.photo,
    CatalogueBrand b => b.photo,
    _ => null,
  };

  /// After the row is saved (a new one needs its id): its photo as picked; false = it failed (the sheet still
  /// closes: Save again would add the row twice). No [context] here: the sheet may be closed by now.
  Future<bool> _savePhoto(String kind, int id) async {
    try {
      if (_photoPath != null || _photoUrl != null) {
        await _repo.setCataloguePhoto(
          kind,
          id,
          path: _photoPath,
          url: _photoUrl,
        );
      } else if (_photoRemoved && _savedPhoto != null) {
        await _repo.removeCataloguePhoto(kind, id);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  List<String> _candidates = const [];
  bool _searching = false;

  /// "Cari dengan AI" for a brand's logo: its site's pictures to pick from (metered); nothing saved.
  Future<void> _searchPhoto() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    if (name.length < 2) return;
    setState(() => _searching = true);
    try {
      final found = await _repo.brandPhotoCandidates(name);
      if (!mounted) return;
      setState(() => _candidates = found);
      if (found.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l.catalogueLogoNone)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// The pictures "Cari dengan AI" found: one tap takes it (kept on Save).
  Widget _candidateGrid() => Wrap(
    spacing: spaceS,
    runSpacing: spaceS,
    children: [
      for (final (i, url) in _candidates.indexed)
        InkWell(
          key: ValueKey('photo-candidate-$i'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _photoUrl = url;
            _photoPath = null;
            _photoRemoved = false;
            _candidates = const [];
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Notebook.of(context).mist, // a white logo still shows
              child: Image.network(
                url,
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.square(dimension: 72),
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> _pickPhoto() async {
    final l = AppLocalizations.of(context);
    final source = await showPhotoSourceSheet(context, camera: l.coverCamera);
    if (source == null || !mounted) return;
    final pick =
        widget.pick ??
        (context, source) => pickPhoto(
          context,
          ratios: [('1:1', 1)], // shown square everywhere
          maxSide: 512, // a thumbnail at most: decoded whole on every list row
          source: source,
        );
    final path = await pick(context, source);
    if (path == null || !mounted) return;
    setState(() {
      _photoPath = path;
      _photoUrl = null;
      _photoRemoved = false;
    });
  }

  /// The photo as it will be saved: a local pick, a fill's link, the saved one, or none (the pick button).
  Widget _photoField(AppLocalizations l) {
    const side = 72.0;
    final Widget? shown = switch ((
      _photoPath,
      _photoUrl,
      _photoRemoved ? null : _savedPhoto,
    )) {
      (final path?, _, _) => Image.file(
        File(path),
        width: side,
        height: side,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.square(dimension: side),
      ),
      (_, final url?, _) => Image.network(
        url,
        width: side,
        height: side,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.square(dimension: side),
      ),
      (_, _, final id?) => CataloguePhoto(id, size: side),
      _ => null,
    };
    if (shown == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const ValueKey('catalogue-photo-pick'),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(l.catalogueProductPhoto),
          onPressed: _busy ? null : _pickPhoto,
        ),
      );
    }
    return Row(
      key: const ValueKey('catalogue-photo'),
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: shown),
        const SizedBox(width: spaceS),
        IconButton(
          key: const ValueKey('catalogue-photo-pick'),
          tooltip: l.catalogueProductPhotoChange,
          icon: const Icon(Icons.photo_camera_outlined),
          onPressed: _busy ? null : _pickPhoto,
        ),
        IconButton(
          key: const ValueKey('catalogue-photo-remove'),
          tooltip: l.ownerMessagePhotoRemove,
          icon: const Icon(Icons.close),
          onPressed: _busy
              ? null
              : () => setState(() {
                  _photoPath = null;
                  _photoUrl = null;
                  _photoRemoved = true;
                }),
        ),
      ],
    );
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
            _row == null ? '${l.catalogueAdd}: $title' : title,
            style: text.titleMedium,
          ),
          if (widget.kind == CatalogueKind.products) ...[
            gap,
            TextField(
              key: const ValueKey('catalogue-fill'),
              controller: _fillFrom,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.catalogueFillFrom,
                suffixIcon: IconButton(
                  key: const ValueKey('catalogue-scan'),
                  tooltip: l.catalogueScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _filling ? null : _scan,
                ),
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
            if (_fill?.similar
                    .where((p) => p.id != (_row as CatalogueProduct?)?.id)
                    .toList()
                case final similar? when similar.isNotEmpty) ...[
              gap,
              Text(l.catalogueSimilar),
              for (final p in similar)
                BaseTile(
                  key: ValueKey('catalogue-similar-${p.id}'),
                  style: TileStyle.plain,
                  dense: true,
                  title: p.name,
                  subtitle: [
                    ?p.brand,
                    if (p.size != null)
                      '${_sizeText(p.size)} ${p.unit ?? ''}'.trim(),
                  ].join(' · '),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editInstead(p),
                ),
            ],
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
            gap,
            _photoField(l),
            const SizedBox(height: spaceXs),
            Align(
              alignment: Alignment.centerRight,
              child: AiButton(
                key: const ValueKey('catalogue-photo-search'),
                label: l.catalogueLogoSearch,
                busy: _searching,
                onPressed: _busy ? null : _searchPhoto,
              ),
            ),
            if (_candidates.isNotEmpty) ...[gap, _candidateGrid()],
          ],
          if (widget.kind == CatalogueKind.products) ...[
            gap,
            _photoField(l),
            // Added with the product on Save, unless the owner picks another brand.
            if (_fill case final f?
                when f.brandIsNew &&
                    !_brandAdded &&
                    _orNull(_brand) == null) ...[
              gap,
              Text(l.catalogueNewBrand(f.brand!)),
              if (f.maker case final m?)
                Text(
                  l.catalogueMadeBy(
                    m.country == null ? m.name : '${m.name}, ${m.country}',
                    Uri.tryParse(m.source)?.host ?? m.source,
                  ),
                  style: text.bodySmall?.copyWith(
                    color: Notebook.of(context).inkSoft,
                  ),
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
          ListenableBuilder(
            listenable: _name,
            builder: (_, _) => PanelActions(
              children: [
                if (_row != null)
                  BusyButton(
                    key: const ValueKey('catalogue-delete'),
                    icon: Icons.delete_outline,
                    label: l.delete,
                    busyLabel: l.delete,
                    busy: _deleting,
                    kind: BusyButtonKind.danger,
                    onPressed: _busy ? null : _delete,
                  ),
                BusyButton(
                  key: const ValueKey('catalogue-save'),
                  icon: Icons.check,
                  label: l.save,
                  busyLabel: l.ownerSaving,
                  busy: _busy && !_deleting,
                  kind: BusyButtonKind.filled,
                  onPressed: _busy || _name.text.trim().length < 2
                      ? null
                      : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
