import 'dart:async';

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

  /// What the stars show: changes at once on a tap, before the server answers.
  late int? _mine = widget.rating.mine;

  /// What the server last confirmed: an error goes back to it.
  late int? _saved = widget.rating.mine;

  // Taps are saved after a short pause, and one request at a time: tapping 1-2-3-4-5 quickly sends only 5.
  static const _settle = Duration(milliseconds: 450);
  Timer? _debounce;
  bool _sending = false;

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
    final idle = !_sending && !(_debounce?.isActive ?? false);
    if (idle && oldWidget.rating != widget.rating) {
      _rating = widget.rating;
      _mine = _saved = widget.rating.mine;
    }
  }

  @override
  void dispose() {
    // Left the page within the pause: still save the last tap (nothing left to show an error on).
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      if (_mine != _saved) widget.onRate!(_mine).ignore();
    }
    super.dispose();
  }

  bool get _canRate => widget.rating.canRate && widget.onRate != null;

  Future<void> _tap(int stars) async {
    if (!_canRate) return;
    final clear = _mine == stars;
    if (clear && _rating.myReview) {
      final l = AppLocalizations.of(context);
      final ok = await showNotebookDialog(
        context,
        message: l.reviewRemoveRatingConfirm,
        tone: DialogTone.danger,
        confirmLabel: l.reviewRemove,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _mine = clear ? null : stars);
    _debounce?.cancel();
    _debounce = Timer(_settle, _save);
  }

  /// Sends what the stars show now, if the server does not have it yet. A tap during the request is sent after it.
  Future<void> _save() async {
    if (_sending || !mounted) return;
    final want = _mine;
    if (want == _saved) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _sending = true;
    try {
      final updated = await widget.onRate!(want);
      if (!mounted) return;
      _saved = updated.mine;
      setState(() {
        _rating = updated;
        if (_mine == want) _mine = updated.mine;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mine = _saved);
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      _sending = false;
    }
    if (mounted && !(_debounce?.isActive ?? false) && _mine != _saved) {
      await _save();
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
          onTap: () => _tap(n),
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
                    onTapUp: (d) => _tap(_starAt(d.localPosition.dx)),
                    onHorizontalDragStart: (d) => _dragTo(d.localPosition.dx),
                    onHorizontalDragUpdate: (d) => _dragTo(d.localPosition.dx),
                    onHorizontalDragEnd: (_) => _dragEnd(),
                    onHorizontalDragCancel: () => setState(() => _drag = null),
                    child: row,
                  )
                else
                  row,
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
