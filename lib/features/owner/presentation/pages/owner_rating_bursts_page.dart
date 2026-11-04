import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';

/// Branches rated by several new accounts this week (maybe fake accounts). The owner reads who rated and deletes
/// the fake ratings; there is no automatic action.
class OwnerRatingBurstsPage extends StatefulWidget {
  const OwnerRatingBurstsPage({super.key});

  @override
  State<OwnerRatingBurstsPage> createState() => _OwnerRatingBurstsPageState();
}

class _OwnerRatingBurstsPageState extends State<OwnerRatingBurstsPage> {
  List<RatingBurst>? _bursts;
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
      final bursts = await context.read<OwnerRepository>().ratingBursts();
      if (mounted) {
        setState(() {
          _bursts = bursts;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(BurstRating r) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<OwnerRepository>();
    final ok = await showNotebookDialog(
      context,
      message: l.ownerRatingDeleteConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.ownerRatingDelete,
    );
    if (!ok) return;
    try {
      await repo.deleteRating(r.id);
      if (mounted) await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final bursts = _bursts;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.ownerRatingBursts),
      ),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: bursts == null
            ? null
            : NotebookPage(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (bursts.isEmpty)
                      NotebookRow(
                        minHeight: 110,
                        mark: Icon(
                          Icons.check_circle_outline,
                          color: nb.pandan,
                        ),
                        child: Text(l.ownerRatingBurstsEmpty),
                      )
                    else
                      for (final b in bursts) ...[
                        NotebookHeading([b.restaurant, ?b.label].join(' · ')),
                        NotebookRow(
                          mark: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: nb.margin,
                          ),
                          child: Text(l.ownerRatingBurstNew(b.newAccounts)),
                        ),
                        for (final r in b.ratings)
                          _RatingRow(rating: r, onDelete: () => _delete(r)),
                      ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.onDelete});

  final BurstRating rating;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = MaterialLocalizations.of(context);
    final r = rating;
    return NotebookRow(
      trailing: IconButton(
        tooltip: l.ownerRatingDelete,
        icon: Icon(Icons.delete_outline, color: nb.margin),
        onPressed: onDelete,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.email,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            [
              l.ownerRatingJoined(m.formatShortDate(r.joinedAt.toLocal())),
              if (!r.emailVerified) l.emailNotVerified,
            ].join(' · '),
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          Row(
            children: [
              for (var n = 1; n <= 5; n++)
                Icon(
                  n <= r.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: n <= r.stars ? nb.kunyit : nb.inkSoft,
                ),
              if (r.hidden)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    l.ownerReviewHidden,
                    style: text.bodySmall?.copyWith(color: nb.margin),
                  ),
                ),
            ],
          ),
          if (r.text case final t? when t.isNotEmpty)
            Text(t, style: text.bodyMedium),
        ],
      ),
    );
  }
}
