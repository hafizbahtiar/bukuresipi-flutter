import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../widgets/catalogue_edit_sheet.dart';

/// Owner > Catalogue: products, brands and makers, searched, added, edited, deleted. Server design:
/// bukuresipi-hono docs/superpowers/specs/2026-11-26-brands-design.md; keeping docs/plans in step: docs/catalogue.md.
class OwnerCataloguePage extends StatefulWidget {
  const OwnerCataloguePage({super.key});

  @override
  State<OwnerCataloguePage> createState() => _OwnerCataloguePageState();
}

class _OwnerCataloguePageState extends State<OwnerCataloguePage> {
  final _search = TextEditingController();
  CatalogueKind _kind = CatalogueKind.products;
  List<Object> _rows = const [];
  int? _next;
  List<String> _countries = const [];
  List<String> _units = const [];
  Object? _error;
  bool _loading = true;
  bool _more = false;
  Timer? _debounce;
  int _asked = 0;

  OwnerRepository get _repo => context.read<OwnerRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<(List<Object>, int?)> _page(int offset) async {
    final q = _search.text;
    switch (_kind) {
      case CatalogueKind.makers:
        final p = await _repo.makers(query: q, offset: offset);
        return (p.items, p.next);
      case CatalogueKind.brands:
        final (p, countries) = await _repo.brands(query: q, offset: offset);
        _countries = countries;
        return (p.items, p.next);
      case CatalogueKind.products:
        final (p, units) = await _repo.products(query: q, offset: offset);
        _units = units;
        return (p.items, p.next);
    }
  }

  Future<void> _load() async {
    final mine = ++_asked;
    setState(() => _loading = true);
    try {
      final (rows, next) = await _page(0);
      if (mounted && mine == _asked) {
        setState(() {
          _rows = rows;
          _next = next;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && mine == _asked) setState(() => _error = e);
    } finally {
      if (mounted && mine == _asked) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final l = AppLocalizations.of(context);
    final mine = _asked;
    setState(() => _more = true);
    try {
      final (rows, next) = await _page(_next!);
      if (mounted && mine == _asked) {
        setState(() {
          _rows = [..._rows, ...rows];
          _next = next;
        });
      }
    } catch (e) {
      if (mounted) _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit([Object? row]) async {
    final l = AppLocalizations.of(context);
    final done = await showBaseSheet<String>(
      context,
      builder: (_) => CatalogueEditSheet(
        kind: _kind,
        row: row,
        countries: _countries,
        units: _units,
      ),
    );
    if (done == null || !mounted) return;
    _snack(done == 'deleted' ? l.catalogueDeleted : l.catalogueSaved);
    _load();
  }

  Future<void> _copyRows() async {
    final l = AppLocalizations.of(context);
    try {
      final rows = await _repo.catalogueRows();
      if (!mounted) return;
      await showBaseSheet<void>(context, builder: (_) => _RowsSheet(rows));
    } catch (e) {
      if (mounted) _snack(errorText(l, e));
    }
  }

  ({String title, String subtitle}) _describe(Object row) {
    final l = AppLocalizations.of(context);
    String join(List<String?> parts) =>
        parts.whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return switch (row) {
      CatalogueMaker m => (
        title: m.name,
        subtitle: l.catalogueBrandCount(m.brands),
      ),
      CatalogueBrand b => (
        title: b.name,
        subtitle: join([
          b.maker,
          b.country,
          l.catalogueProductCount(b.products),
        ]),
      ),
      CatalogueProduct p => (
        title: p.name,
        subtitle: join([
          p.brand,
          p.ingredient,
          if (p.size != null)
            '${p.size! % 1 == 0 ? p.size!.toInt() : p.size} ${p.unit ?? ''}'
                .trim(),
        ]),
      ),
      _ => (title: '$row', subtitle: ''),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerCatalogue),
        actions: [
          IconButton(
            key: const ValueKey('catalogue-add'),
            tooltip: l.catalogueAdd,
            icon: const Icon(Icons.add),
            onPressed: () => _edit(),
          ),
          IconButton(
            key: const ValueKey('catalogue-more'),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_vert),
            onPressed: () => showActionSheet(
              context,
              actions: [
                MenuAction(
                  icon: Icons.content_copy,
                  label: l.ownerCopyRows,
                  onTap: _copyRows,
                ),
              ],
            ),
          ),
        ],
      ),
      body: WidePage(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spaceM),
              child: NotebookSegmented<CatalogueKind>(
                segments: [
                  NotebookSegment(
                    value: CatalogueKind.products,
                    label: l.catalogueProducts,
                  ),
                  NotebookSegment(
                    value: CatalogueKind.brands,
                    label: l.catalogueBrands,
                  ),
                  NotebookSegment(
                    value: CatalogueKind.makers,
                    label: l.catalogueMakers,
                  ),
                ],
                selected: _kind,
                onChanged: (k) {
                  setState(() {
                    _kind = k;
                    _rows = const [];
                  });
                  _load();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(spaceM, spaceXs, spaceM, 0),
              child: TextField(
                key: const ValueKey('catalogue-search'),
                controller: _search,
                decoration: InputDecoration(
                  labelText: l.catalogueSearch,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _searchChanged,
              ),
            ),
            Expanded(
              child: LoadView(
                loading: _loading && _rows.isEmpty,
                error: _error,
                onReload: _load,
                child: _rows.isEmpty
                    ? (_loading
                          ? null
                          : ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(spaceL),
                                  child: Text(
                                    l.catalogueEmpty,
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium?.copyWith(
                                      color: nb.inkSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ))
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          top: spaceS,
                          bottom: spaceL,
                        ),
                        itemCount: _rows.length + (_next == null ? 0 : 1),
                        itemBuilder: (context, i) {
                          if (i == _rows.length) {
                            return Center(
                              child: TextButton(
                                key: const ValueKey('catalogue-load-more'),
                                onPressed: _more ? null : _loadMore,
                                child: Text(l.loadMore),
                              ),
                            );
                          }
                          final row = _rows[i];
                          final d = _describe(row);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: spaceXs),
                            child: BaseTile(
                              key: ValueKey('catalogue-row-${d.title}'),
                              title: d.title,
                              subtitle: d.subtitle,
                              dense: true,
                              onTap: () => _edit(row),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The added and changed rows, to paste into docs/plans/ (the seed for new and test databases).
class _RowsSheet extends StatelessWidget {
  const _RowsSheet(this.rows);

  final ({String makers, String brands, String products}) rows;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final blocks = [
      ('manufacturer.md', rows.makers),
      ('brand.md', rows.brands),
      ('product.md', rows.products),
    ].where((b) => b.$2.isNotEmpty).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.ownerCopyRows, style: text.titleMedium),
          const SizedBox(height: spaceXs),
          Text(
            blocks.isEmpty ? l.ownerCopyRowsNone : l.catalogueRowsHint,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          const SizedBox(height: spaceS),
          for (final (file, block) in blocks) ...[
            Row(
              children: [
                Expanded(child: Text(file, style: text.titleSmall)),
                IconButton(
                  tooltip: l.ownerCopyRows,
                  icon: const Icon(Icons.content_copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: block));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l.ownerCopied)));
                    }
                  },
                ),
              ],
            ),
            SelectableText(
              block,
              style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: spaceM),
          ],
        ],
      ),
    );
  }
}
