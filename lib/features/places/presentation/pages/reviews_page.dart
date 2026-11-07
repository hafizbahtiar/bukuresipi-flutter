import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/rating.dart';
import '../../domain/review.dart';
import '../places_controller.dart';
import '../widgets/notebook_rating.dart';
import '../widgets/report_review_sheet.dart';
import '../widgets/review_sheet.dart';

/// The public review list of one canonical branch, with quick rating, review editing, votes and reports.
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  ReviewPage? _page;
  Object? _error;
  bool _loading = true;
  bool _more = false;
  final _voting = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final places = context.read<PlacesController>();
    setState(() {
      _loading = true;
      if (more) _more = true;
    });
    try {
      final page = await places.reviews(
        widget.branchId,
        offset: more ? _page?.nextOffset ?? 0 : 0,
      );
      if (!mounted) return;
      setState(() {
        _page = more && _page != null
            ? page.copyWith(reviews: [..._page!.reviews, ...page.reviews])
            : page;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  List<Review> get _reviews => _page?.reviews ?? const [];

  Review? get _mine => _reviews.where((r) => r.mine).firstOrNull;

  void _replaceRating(RatingSummary rating) {
    if (_page == null) return;
    setState(() => _page = _page!.copyWith(rating: rating));
  }

  void _replaceReview(String id, Review Function(Review) change) {
    setState(() {
      _page = _page!.copyWith(
        reviews: [for (final r in _reviews) r.id == id ? change(r) : r],
      );
    });
  }

  Future<RatingSummary> _rate(int? stars) async {
    final rating = await context.read<PlacesController>().setRating(
      widget.branchId,
      stars,
    );
    if (mounted) _replaceRating(rating);
    return rating;
  }

  Future<void> _write() async {
    final page = _page;
    if (page == null) return;
    final own = _mine;
    final places = context.read<PlacesController>();
    await showNotebookSheet<bool>(
      context,
      builder: (_) => ReviewSheet(
        initialStars: page.rating.mine ?? 5,
        initialText: own?.text,
        onSave: (stars, text) async {
          final result = await places.saveReview(widget.branchId, stars, text);
          _replaceRating(result.rating);
        },
        onRemove: own == null
            ? null
            : () async {
                final rating = await places.removeReview(widget.branchId);
                _replaceRating(rating);
              },
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _vote(Review review, ReviewVote vote) async {
    if (_voting.contains(review.id)) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    final next = review.votes.mine == vote ? null : vote;
    setState(() => _voting.add(review.id));
    try {
      final votes = await places.voteReview(review.id, next);
      if (!mounted) return;
      _replaceReview(review.id, (r) => r.copyWith(votes: votes));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _voting.remove(review.id));
    }
  }

  Future<void> _report(Review review) async {
    final places = context.read<PlacesController>();
    final reported = await showNotebookSheet<bool>(
      context,
      builder: (_) => ReportReviewSheet(
        onSubmit: (reason, note) =>
            places.reportReview(review.id, reason, note),
      ),
    );
    if (reported == true && mounted) {
      _replaceReview(review.id, (r) => r.copyWith(reported: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final page = _page;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.reviewsTitle)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: page == null
            ? null
            : NotebookPage(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    NotebookHeading(page.branchLabel ?? page.branchName),
                    NotebookRow(
                      mark: Icon(
                        Icons.star_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: NotebookRating(
                        rating: page.rating,
                        onRate: _rate,
                        hint: page.rating.canRate
                            ? null
                            // canRate needs a save and a confirmed email; name the one that is missing.
                            : context
                                      .watch<AuthController?>()
                                      ?.user
                                      ?.emailVerified ==
                                  false
                            ? l.reviewVerifyEmail
                            : l.reviewNotSaved,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        notebookGutter + 10,
                        12,
                        20,
                        10,
                      ),
                      child: FilledButton.icon(
                        onPressed: page.rating.canRate ? _write : null,
                        icon: Icon(
                          _mine == null
                              ? Icons.rate_review_outlined
                              : Icons.edit_outlined,
                        ),
                        label: Text(
                          _mine == null ? l.reviewWrite : l.reviewEdit,
                        ),
                      ),
                    ),
                    if (_reviews.isEmpty)
                      NotebookRow(
                        mark: const Icon(Icons.chat_bubble_outline, size: 18),
                        child: Text(l.reviewsEmpty),
                      )
                    else
                      for (final review in _reviews)
                        _ReviewCard(
                          review: review,
                          busy: _voting.contains(review.id),
                          onVote: (vote) => _vote(review, vote),
                          onReport: () => _report(review),
                          onEdit: _write,
                          onRemove: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await context
                                  .read<PlacesController>()
                                  .removeReview(widget.branchId);
                              if (mounted) await _load();
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(errorText(l, e))),
                              );
                            }
                          },
                        ),
                    if (page.nextOffset != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: OutlinedButton(
                          onPressed: _loading ? null : () => _load(more: true),
                          child: _more
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l.loadMore),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.busy,
    required this.onVote,
    required this.onReport,
    required this.onEdit,
    required this.onRemove,
  });

  final Review review;
  final bool busy;
  final ValueChanged<ReviewVote> onVote;
  final VoidCallback onReport;
  final VoidCallback onEdit;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final date = MaterialLocalizations.of(context)
        .formatShortDate(review.createdAt.toLocal());
    return NotebookRow(
      mark: Icon(Icons.star_rounded, size: 18, color: nb.kunyit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.author,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(date, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
            ],
          ),
          Row(
            children: [
              for (var n = 1; n <= 5; n++)
                Icon(
                  n <= review.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: n <= review.stars ? nb.kunyit : nb.inkSoft,
                ),
              if (review.hidden)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    l.reviewHidden,
                    style: text.bodySmall?.copyWith(color: nb.margin),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(review.text, style: text.bodyMedium),
          if (!review.mine && !review.hidden)
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : () => onVote(ReviewVote.up),
                  icon: Icon(
                    review.votes.mine == ReviewVote.up
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    size: 16,
                  ),
                  label: Text('${review.votes.up}'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => onVote(ReviewVote.down),
                  icon: Icon(
                    review.votes.mine == ReviewVote.down
                        ? Icons.thumb_down
                        : Icons.thumb_down_outlined,
                    size: 16,
                  ),
                  label: Text('${review.votes.down}'),
                ),
                TextButton.icon(
                  onPressed: review.reported ? null : onReport,
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(
                    review.reported ? l.reviewReported : l.reviewReport,
                  ),
                ),
              ],
            ),
          if (review.mine)
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l.reviewEdit),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await showNotebookDialog(
                      context,
                      message: l.reviewRemoveConfirm,
                      tone: DialogTone.danger,
                      confirmLabel: l.reviewRemove,
                    );
                    if (ok) await onRemove();
                  },
                  child: Text(l.reviewRemove),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
