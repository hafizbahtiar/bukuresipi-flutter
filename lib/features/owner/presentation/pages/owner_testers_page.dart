import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// The website's Android tester signups. "Copy all" puts the emails on the clipboard, one per line, for the Play
/// Console closed test (Google sends the invites).
class OwnerTestersPage extends StatefulWidget {
  const OwnerTestersPage({super.key});

  @override
  State<OwnerTestersPage> createState() => _OwnerTestersPageState();
}

class _OwnerTestersPageState extends State<OwnerTestersPage> {
  List<Tester>? _testers;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final testers = await context.read<OwnerRepository>().testers();
      if (mounted) {
        setState(() {
          _testers = testers;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(List<Tester> testers) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: testers.map((t) => t.email).join('\n')),
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l.ownerTestersCopied(testers.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = MaterialLocalizations.of(context);
    final testers = _testers;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerTesters),
        actions: [
          if (testers != null && testers.isNotEmpty)
            IconButton(
              tooltip: l.ownerTestersCopy,
              icon: const Icon(Icons.copy_all),
              onPressed: () => _copy(testers),
            ),
        ],
      ),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: testers == null
            ? null
            : NotebookPage(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (testers.isEmpty)
                        NotebookRow(
                          minHeight: 110,
                          mark: Icon(Icons.people_outline, color: nb.inkSoft),
                          child: Text(l.ownerTestersEmpty),
                        ),
                      for (final t in testers)
                        NotebookRow(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(t.email),
                              Text(
                                '${m.formatShortDate(t.joinedAt.toLocal())} · ${t.lang.toUpperCase()}',
                                style: text.bodySmall?.copyWith(
                                  color: nb.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
