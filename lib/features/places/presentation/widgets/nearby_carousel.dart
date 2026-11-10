import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/nearby_branch.dart';

/// Nearby branches as a horizontal, snapping strip of compact notebook cards along the bottom of the map.
class NearbyCarousel extends StatefulWidget {
  const NearbyCarousel({
    super.key,
    required this.places,
    required this.onTap,
    this.selectedBranchId,
    this.onSelected,
  });

  /// Grows with the phone's text size: the card holds up to four lines of text.
  static double heightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(100);

  final List<NearbyBranch> places;
  final ValueChanged<NearbyBranch> onTap;

  /// The card to reveal (for example after tapping its circle on the map).
  final String? selectedBranchId;

  /// Called when the user snaps to another card; the map centres on it.
  final ValueChanged<NearbyBranch>? onSelected;

  @override
  State<NearbyCarousel> createState() => _NearbyCarouselState();
}

class _NearbyCarouselState extends State<NearbyCarousel> {
  // Wide enough for a long name on one line; a 360 dp phone still shows the next card peeking in.
  static const _cardWidth = 300.0;
  static const _gap = 8.0;
  static const _extent = _cardWidth + _gap;

  late final ScrollController _controller;
  int _selectedIndex = -1;
  bool _animating = false;

  int _indexOf(String? id) =>
      id == null ? -1 : widget.places.indexWhere((p) => p.branchId == id);

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _selectedIndex = _indexOf(widget.selectedBranchId);
    if (_selectedIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_scrollTo(_selectedIndex));
      });
    }
  }

  @override
  void didUpdateWidget(NearbyCarousel old) {
    super.didUpdateWidget(old);
    final index = _indexOf(widget.selectedBranchId);
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_scrollTo(index));
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(int index) async {
    if (!_controller.hasClients) return;
    _animating = true;
    try {
      await _controller.animateTo(
        index * _extent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _animating = false;
    }
  }

  void _tapCard(int index) {
    if (index == _selectedIndex) {
      widget.onTap(widget.places[index]);
      return;
    }
    // A side card is the "next card" the user wants; focus it instead of opening detail.
    final place = widget.places[index];
    setState(() => _selectedIndex = index);
    unawaited(_scrollTo(index));
    widget.onSelected?.call(place);
  }

  bool _onScroll(ScrollNotification notification) {
    if (_animating ||
        notification is! ScrollEndNotification ||
        widget.places.isEmpty) {
      return false;
    }
    final index = (notification.metrics.pixels / _extent).round().clamp(
      0,
      widget.places.length - 1,
    );
    final target = index * _extent;
    if ((notification.metrics.pixels - target).abs() > 1) {
      // The scroll activity is still unwinding here; start the snap on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_scrollTo(index));
      });
    }
    if (index != _selectedIndex) {
      final place = widget.places[index];
      _selectedIndex = index;
      // Scroll notifications arrive during layout: rebuild and move the camera after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {});
        widget.onSelected?.call(place);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.places.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: NearbyCarousel.heightOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Centre the selected card: the side padding is exactly the space a card leaves on each side.
          // With this padding, every snap target is simply index * extent.
          final side = ((constraints.maxWidth - _cardWidth) / 2)
              .clamp(16.0, double.infinity)
              .toDouble();
          return NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: side, vertical: 2),
              itemCount: widget.places.length,
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.only(
                  right: i == widget.places.length - 1 ? 0 : _gap,
                ),
                child: SizedBox(
                  key: ValueKey('nearby-card-${widget.places[i].branchId}'),
                  width: _cardWidth,
                  height: NearbyCarousel.heightOf(context) - 4,
                  child: NearbyCard(
                    place: widget.places[i],
                    selected: i == _selectedIndex,
                    onTap: () => _tapCard(i),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One nearby restaurant: name, distance, address, cuisine and the post's halal quote. Map carousel and Home feed.
class NearbyCard extends StatelessWidget {
  const NearbyCard({
    super.key,
    required this.place,
    this.selected = false,
    required this.onTap,
  });

  final NearbyBranch place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final label = place.label?.trim();
    final address = place.address?.trim();
    final under = label != null && label.isNotEmpty && label != place.name
        ? label
        : (address != null && address.isNotEmpty ? address : null);
    final addressLine =
        address != null && address.isNotEmpty && address != under
        ? address
        : null;
    final quote = place.halalQuote?.trim();
    final cuisine = place.cuisine?.trim();
    return Material(
      color: nb.paper,
      elevation: selected ? 4 : 2,
      shadowColor: nb.ink.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? nb.pandan : nb.line,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: nb.mist,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: nb.line),
                ),
                child: Icon(Icons.storefront, size: 18, color: nb.pandanDeep),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _DistancePill(
                          label: distanceText(place.distanceM),
                          background: nb.mist,
                          foreground: nb.pandanDeep,
                        ),
                      ],
                    ),
                    if (under != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        under,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                    ],
                    if (addressLine != null)
                      Text(
                        addressLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: nb.inkSoft.withValues(alpha: 0.8),
                        ),
                      ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (cuisine != null && cuisine.isNotEmpty) ...[
                          _InfoTag(
                            text: cuisine,
                            color: nb.inkSoft,
                            background: nb.mist,
                            border: nb.line,
                          ),
                          if (quote != null && quote.isNotEmpty)
                            const SizedBox(width: 6),
                        ],
                        if (quote != null && quote.isNotEmpty)
                          Expanded(
                            child: Text(
                              '“$quote”',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: nb.inkSoft,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (place.saved)
                          _InfoTag(
                            text: l.nearbySavedTag,
                            icon: Icons.bookmark,
                            color: nb.pandanDeep,
                            background: nb.mist,
                            border: nb.line,
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: nb.inkSoft,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
    ),
  );
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({
    required this.text,
    required this.color,
    required this.background,
    required this.border,
    this.icon,
  });

  final String text;
  final Color color;
  final Color background;
  final Color border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon case final icon?) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    ),
  );
}
