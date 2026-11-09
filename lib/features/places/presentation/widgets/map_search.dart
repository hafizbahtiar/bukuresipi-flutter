import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/place.dart';

/// Pinned branches of [places] whose restaurant name, branch label or address contains [query] (case-insensitive).
List<(Place, Branch)> searchPins(List<Place> places, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  bool hit(String? s) => s?.toLowerCase().contains(q) ?? false;
  return [
    for (final p in places)
      for (final b in p.pins)
        if (hit(p.restaurant.name) || hit(b.label) || hit(b.where)) (p, b),
  ];
}

/// Server search: (query, submit) -> places near the map's centre.
typedef PlaceSearch = Future<List<PlaceHit>> Function(
  String query, {
  required bool submit,
});

/// The map's search, a bar floating on the map. Your saved places first (on the phone), then other places from the
/// server: while typing, what the app already knows; on Search, also OpenStreetMap when that is little. The results
/// drop down under the bar, each row easing in; a pick goes to [onPicked] (a (Place, Branch) of yours or a
/// [PlaceHit]) and the bar empties. Back closes the results first.
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({
    super.key,
    required this.places,
    required this.search,
    required this.onPicked,
    this.reserveBottom = 0,
  });

  final List<Place> places;
  final PlaceSearch search;
  final ValueChanged<Object> onPicked;

  /// Space the results leave free above the keyboard (the page's nearby cards).
  final double reserveBottom;

  /// The bar's own height: the page lays its buttons out below it.
  static const height = 44.0;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  bool _submitted = false;

  // One request per query and kind, kept while the bar lives.
  final _asked = <(String, bool), Future<List<PlaceHit>>>{};

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (_text.text.trim() == _query) return; // a cursor move
      setState(() {
        _query = _text.text.trim();
        _submitted = false;
      });
    });
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  static const _morph = Duration(milliseconds: 260);

  bool get _open => _query.isNotEmpty && (_focus.hasFocus || _submitted);

  Future<List<PlaceHit>> _ask(String q, bool submit) => _asked[(q, submit)] ??=
      // Typing: wait for a pause, and drop the request if the query moved on.
      Future<void>.delayed(Duration(milliseconds: submit ? 0 : 300)).then(
        (_) => q != _query
            ? const <PlaceHit>[]
            : widget.search(q, submit: submit).catchError((Object _) {
                _asked.remove((q, submit)); // tried again next time
                return const <PlaceHit>[];
              }),
      );

  void _close() {
    _text.clear();
    _focus.unfocus();
  }

  void _pick(Object hit) {
    _close();
    widget.onPicked(hit);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final mq = MediaQuery.of(context);
    final typing = _text.text.isNotEmpty;
    return PopScope(
      canPop: !_open && !_focus.hasFocus,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _close();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Back, outside the field, always there: while searching it closes the search, else it leaves the map.
              Material(
                color: nb.paper,
                elevation: 3,
                shadowColor: nb.ink.withValues(alpha: 0.3),
                shape: CircleBorder(side: BorderSide(color: nb.line)),
                child: SizedBox.square(
                  dimension: MapSearchBar.height,
                  child: IconButton(
                    key: const ValueKey('map-search-back'),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    iconSize: 20,
                    icon: const BackButtonIcon(),
                    onPressed: () => _focus.hasFocus || _open
                        ? _close()
                        : context.canPop()
                        ? context.pop()
                        : context.go('/'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: nb.paper,
                  elevation: 3,
                  shadowColor: nb.ink.withValues(alpha: 0.3),
                  shape: StadiumBorder(side: BorderSide(color: nb.line)),
                  child: SizedBox(
                    height: MapSearchBar.height,
                    // One icon: a search glass on the left that turns into ✕ and slides right once you type.
                    child: Stack(
                      children: [
                        AnimatedPadding(
                          duration: _morph,
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.only(
                            left: typing ? 16 : 40,
                            right: typing ? 40 : 16,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              key: const ValueKey('map-search'),
                              controller: _text,
                              focusNode: _focus,
                              textInputAction: TextInputAction.search,
                              // The pill is the field's box: no border or fill of its own, focused or not.
                              decoration: InputDecoration(
                                hintText: l.mapSearchHint,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) =>
                                  setState(() => _submitted = true),
                            ),
                          ),
                        ),
                        AnimatedAlign(
                          duration: _morph,
                          curve: Curves.easeOutCubic,
                          alignment: typing
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: IconButton(
                              key: ValueKey(
                                typing ? 'map-search-clear' : 'map-search-icon',
                              ),
                              tooltip: typing
                                  ? MaterialLocalizations.of(context)
                                        .deleteButtonTooltip
                                  : l.mapSearchHint,
                              color: nb.inkSoft,
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              onPressed: typing
                                  ? _text.clear
                                  : _focus.requestFocus,
                              icon: AnimatedSwitcher(
                                duration: _morph,
                                transitionBuilder: (child, a) =>
                                    RotationTransition(
                                      turns: Tween(
                                        begin: 0.75,
                                        end: 1.0,
                                      ).animate(a),
                                      child: FadeTransition(
                                        opacity: a,
                                        child: child,
                                      ),
                                    ),
                                child: Icon(
                                  typing ? Icons.close : Icons.search,
                                  key: ValueKey(typing),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SizeTransition(
                sizeFactor: a,
                alignment: Alignment.topCenter,
                child: ScaleTransition(
                  scale: Tween(begin: 0.96, end: 1.0).animate(a),
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ),
            child: _open
                ? Padding(
                    key: const ValueKey('map-search-results'),
                    padding: const EdgeInsets.only(top: 8),
                    child: ConstrainedBox(
                      // Above the keyboard, below the bar.
                      constraints: BoxConstraints(
                        maxHeight:
                            (mq.size.height -
                                    mq.viewInsets.bottom -
                                    widget.reserveBottom -
                                    mq.padding.top -
                                    MapSearchBar.height -
                                    40)
                                .clamp(120.0, 480.0),
                      ),
                      child: _results(context, l, nb),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, AppLocalizations l, Notebook nb) {
    final q = _query;
    final submit = _submitted;
    final mine = searchPins(widget.places, q);
    final myBranches = {for (final (_, b) in mine) b.id};
    final ask = q.length >= 2 ? _ask(q, submit) : null;
    return Material(
      color: nb.paper,
      elevation: 4,
      shadowColor: nb.ink.withValues(alpha: 0.3),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: nb.line),
      ),
      child: FutureBuilder<List<PlaceHit>>(
        future: ask,
        builder: (context, s) {
          final others = [
            for (final h in s.data ?? const <PlaceHit>[])
              if (!myBranches.contains(h.branchId)) h,
          ];
          final waiting =
              ask != null && s.connectionState != ConnectionState.done;
          final rows = <Widget>[
            for (final (p, b) in mine)
              _Row(
                key: ValueKey('search-mine-${b.id}'),
                icon: Icons.bookmark,
                title: p.restaurant.name,
                subtitle: b.label ?? b.where,
                onTap: () => _pick((p, b)),
              ),
            for (final h in others)
              _Row(
                key: ValueKey('search-hit-${h.branchId ?? h.poiId}'),
                icon: Icons.restaurant,
                title: h.name,
                subtitle: h.address,
                distance: distanceText(h.distanceM),
                onTap: () => _pick(h),
              ),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (waiting)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: nb.pandan,
                  backgroundColor: nb.mist,
                ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: nb.line),
                  // Each row eases in a little after the one above, as the list drops.
                  itemBuilder: (_, i) => _Rise(
                    key: ValueKey(rows[i].key),
                    delay: i.clamp(0, 6) * 40,
                    child: rows[i],
                  ),
                ),
              ),
              if (!waiting && rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    submit ? l.mapSearchNone : l.mapSearchPress,
                    style: TextStyle(color: nb.inkSoft),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A result: an icon in a soft circle, the name, where, and how far.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.distance,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: nb.mist, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: nb.pandan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle case final s?)
                    Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: nb.inkSoft),
                    ),
                ],
              ),
            ),
            if (distance case final d?) ...[
              const SizedBox(width: 10),
              Text(
                d,
                style: text.labelLarge?.copyWith(
                  color: nb.pandan,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts its child in once, [delay] ms late. Keyed by result, so a row already shown never replays.
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 220 + delay),
    curve: Interval(delay / (220 + delay), 1, curve: Curves.easeOutCubic),
    builder: (_, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: child),
    ),
    child: child,
  );
}
