import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/rating.dart';

/// Five notebook-style stars plus the community average: only on the branch's Reviews page, where rating belongs.
/// Elsewhere a [RatingLine] summarises it. The server owns `canRate`.
class NotebookRating extends StatefulWidget {
  const NotebookRating({
    super.key,
    required this.rating,
    this.onRate,
    this.onReviews,
    this.hint,
  });

  final RatingSummary rating;

  /// `null` clears the caller's rating; the response is the fresh server summary.
  final Future<RatingSummary> Function(int? stars)? onRate;

  /// Opens the branch review list. Null hides the link.
  final VoidCallback? onReviews;

  /// Shown when the caller cannot rate (save first / verify email).
  final String? hint;

  @override
  State<NotebookRating> createState() => _NotebookRatingState();
}

class _NotebookRatingState extends State<NotebookRating> {
  late RatingSummary _rating = widget.rating;
  late int? _mine = widget.rating.mine;
  bool _busy = false;

  /// The star under the finger while dragging; saved when the finger lifts.
  int? _drag;

  int _starAt(double dx) => (dx / _starSize).ceil().clamp(1, 5);

  void _dragTo(double dx) {
    final n = _starAt(dx);
    if (n == _drag) return;
    HapticFeedback.selectionClick();
    setState(() => _drag = n);
  }

  void _dragEnd() {
    final n = _drag;
    setState(() => _drag = null);
    // Sliding back to the current rating keeps it (only a tap on it clears).
    if (n != null && n != _mine) _tap(n);
  }

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
    final shown = _drag ?? _mine;
    final stars = <Widget>[
      for (var n = 1; n <= 5; n++)
        _Star(
          key: _canRate ? ValueKey('rating-star-$n') : null,
          filled: shown != null && n <= shown,
          lifted: n == _drag,
          interactive: _canRate,
          label: l.ratingStarLabel(n),
          onTap: _busy ? null : () => _tap(n),
        ),
    ];
    final row = Row(mainAxisSize: MainAxisSize.min, children: stars);
    final summary = _summary(l);
    return Semantics(
      container: true,
      label: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Narrow screens or large text: the stars shrink instead of overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canRate)
                  // Tap a star, or slide a finger along the row: the stars follow it and the rating is saved on lift.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _busy
                        ? null
                        : (d) => _tap(_starAt(d.localPosition.dx)),
                    onHorizontalDragStart: _busy
                        ? null
                        : (d) => _dragTo(d.localPosition.dx),
                    onHorizontalDragUpdate: _busy
                        ? null
                        : (d) => _dragTo(d.localPosition.dx),
                    onHorizontalDragEnd: _busy ? null : (_) => _dragEnd(),
                    onHorizontalDragCancel: () => setState(() => _drag = null),
                    child: row,
                  )
                else
                  row,
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

const _starSize = 40.0;

/// One star: pops in when it fills (easeOutBack) and lifts under a dragging finger.
class _Star extends StatelessWidget {
  const _Star({
    super.key,
    required this.filled,
    required this.lifted,
    required this.interactive,
    required this.label,
    this.onTap,
  });

  final bool filled;
  final bool lifted;
  final bool interactive;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final icon = AnimatedScale(
      scale: lifted ? 1.25 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          key: ValueKey(filled),
          size: 28,
          color: filled ? nb.kunyit : nb.inkSoft,
        ),
      ),
    );
    if (!interactive) {
      return Padding(padding: const EdgeInsets.only(right: 2), child: icon);
    }
    // Taps and drags are read by the row; Semantics keeps each star a button for screen readers.
    return Semantics(
      button: true,
      selected: filled,
      label: label,
      onTap: onTap,
      child: SizedBox.square(
        dimension: _starSize,
        child: Center(child: icon),
      ),
    );
  }
}

/// One wrapping line for lists and sheets: "★ 4.3 · 7 ratings · 2 reviews". Tapping it opens the Reviews page, where
/// the user rates.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.rating, required this.onTap});

  final RatingSummary rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final summary = rating.count == 0
        ? l.ratingNone
        : rating.average == null
        ? '${l.ratingCount(rating.count)} · ${l.ratingNotEnough}'
        : l.ratingAverage(rating.average!.toStringAsFixed(1), rating.count);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  rating.mine == null
                      ? Icons.star_outline_rounded
                      : Icons.star_rounded,
                  size: 18,
                  color: nb.kunyit,
                ),
              ),
              TextSpan(text: ' $summary · '),
              TextSpan(
                text: rating.reviewCount > 0
                    ? l.reviewsCount(rating.reviewCount)
                    : l.reviewsTitle,
                style: TextStyle(
                  color: nb.pandanDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          style: text.bodySmall?.copyWith(color: nb.inkSoft),
        ),
      ),
    );
  }
}
