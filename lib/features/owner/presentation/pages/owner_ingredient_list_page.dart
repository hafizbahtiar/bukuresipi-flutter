import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// Owner > Ingredients and other names: every catalogue ingredient A-Z, searched here (a few hundred); a tap opens
/// its page.
class OwnerIngredientListPage extends StatefulWidget {
  const OwnerIngredientListPage({super.key});

  @override
  State<OwnerIngredientListPage> createState() =>
      _OwnerIngredientListPageState();
}

class _OwnerIngredientListPageState extends State<OwnerIngredientListPage> {
  final _search = TextEditingController();
  List<IngredientRow>? _rows;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await context.read<OwnerRepository>().listIngredients();
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _rows;
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final r in rows ?? const <IngredientRow>[])
        if (q.isEmpty ||
            r.name.toLowerCase().contains(q) ||
            (r.category?.toLowerCase().contains(q) ?? false))
          r,
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerIngredientsShort),
      ),
      body: WidePage(
        child: LoadView(
          loading: _loading,
          error: _error,
          onReload: _load,
          child: rows == null
              ? null
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: spaceL),
                    itemCount: shown.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                            spaceM,
                            0,
                            spaceM,
                            spaceS,
                          ),
                          child: TextField(
                            key: const ValueKey('ingredients-search'),
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: l.ownerGapSearch,
                              prefixIcon: const Icon(Icons.search),
                            ),
                          ),
                        );
                      }
                      final r = shown[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: spaceXs),
                        child: BaseTile(
                          key: ValueKey('ingredient-${r.id}'),
                          dense: true,
                          title: r.name,
                          subtitle: l.ownerIngredientRowSub(
                            r.category ?? l.ownerIngredientNoCategory,
                            r.aliases,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await context.push('/owner/ingredient/${r.id}');
                            _load(); // a rename, a split or a new name
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
