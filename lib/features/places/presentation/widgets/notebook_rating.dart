import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/rating.dart';

/// Five notebook-style stars plus the community average. The server owns `canRate`; the owner of the
/// rating is the only person who can change it.
class NotebookRating extends StatefulWidget {
  const NotebookRating({
    super.key,
    required this.rating,
    this.onRate,
    this.onReviews,
    this.hint,
    this.compact = false,
  });

  final RatingSummary rating;

  /// `null` clears the caller's rating; the response is the fresh server summary.
  final Future<RatingSummary> Function(int? stars)? onRate;

  /// Opens the branch review list. Null hides the link.
  final VoidCallback? onReviews;

  /// Shown when the caller cannot rate (save first / verify email).
  final String? hint;
  final bool compact;

  @override
  State<NotebookRating> createState() => _NotebookRatingState();
}

class _NotebookRatingState extends State<NotebookRating> {
  late RatingSummary _rating = widget.rating;
  late int? _mine = widget.rating.mine;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant NotebookRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy && oldWidget.rating != widget.rating) {
      _rating = widget.rating;
      _mine = widget.rating.mine;
    }
  }

  bool get _canRate => widget.rating.canRate && widget.onRate != null;

  Future<void> _tap(int stars) async {
    if (!_canRate || _busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final oldMine = _mine;
    final clear = _mine == stars;
    if (clear && _rating.myReview) {
      final ok = await showNotebookDialog(
        context,
        message: l.reviewRemoveRatingConfirm,
        tone: DialogTone.danger,
        confirmLabel: l.reviewRemove,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _mine = clear ? null : stars;
      _busy = true;
    });
    try {
      final updated = await widget.onRate!(clear ? null : stars);
      if (!mounted) return;
      setState(() {
        _rating = updated;
        _mine = updated.mine;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mine = oldMine);
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _summary(AppLocalizations l) {
    if (_rating.count == 0) return l.ratingNone;
    if (_rating.average == null) {
      return '${l.ratingCount(_rating.count)} · ${l.ratingNotEnough}';
    }
    return l.ratingAverage(_rating.average!.toStringAsFixed(1), _rating.count);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final stars = <Widget>[];
    for (var n = 1; n <= 5; n++) {
      final filled = _mine != null && n <= _mine!;
      final icon = Icon(
        filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: widget.compact ? 24 : 28,
        color: filled ? nb.kunyit : nb.inkSoft,
      );
      if (!_canRate) {
        stars.add(
          Padding(padding: const EdgeInsets.only(right: 2), child: icon),
        );
      } else {
        stars.add(
          Semantics(
            button: true,
            selected: filled,
            label: l.ratingStarLabel(n),
            child: SizedBox.square(
              dimension: widget.compact ? 36 : 40,
              child: IconButton(
                key: ValueKey('rating-star-$n'),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => _tap(n),
                icon: icon,
              ),
            ),
          ),
        );
      }
    }
    final summary = _summary(l);
    return Semantics(
      container: true,
      label: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...stars,
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          Text(summary, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
          if (_mine != null)
            Text(
              l.ratingYours(_mine!),
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
          if (!_canRate && widget.hint != null)
            Text(
              widget.hint!,
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
          if (widget.onReviews != null)
            TextButton(
              onPressed: widget.onReviews,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 28),
              ),
              child: Text(
                _rating.reviewCount > 0
                    ? l.reviewsCount(_rating.reviewCount)
                    : l.reviewsTitle,
              ),
            ),
        ],
      ),
    );
  }
}
