import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/draft_photos.dart';

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/base_page_transitions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import 'pin_picker_page.dart';
import '../places_controller.dart';
import '../widgets/cover_picker_sheet.dart';
import '../widgets/jakim_check.dart';
import '../widgets/owner_panel.dart';

typedef BranchEdit = ({
  String? label,
  String? address,
  String? city,
  String? state,
  double? lat,
  double? lng,
});

/// Opens the branch edit page (the standard page transition, not the book flip); true = saved.
Future<bool?> showBranchEdit(
  BuildContext context, {
  required WidgetBuilder builder,
}) => Navigator.of(context).push<bool>(standardRoute<bool>(builder));

/// Edit for one branch, as a page (back = cancel). A normal user's edit is private to them; an owner can also choose to change the shared
/// branch. Moving a shared pin claims it as 'owner'; a text-only edit keeps the existing source.
class BranchEditPage extends StatefulWidget {
  const BranchEditPage({
    super.key,
    required this.placeId,
    required this.branch,
    required this.canEditShared,
    required this.onSave,
    this.onSuggest,
  });

  final String placeId;
  final Branch branch;
  final bool canEditShared;
  final Future<void> Function(BranchEdit edit, BranchEditScope scope) onSave;

  /// Owner only: returns a draft to review; it is never saved by this callback.
  final Future<BranchSuggestion> Function()? onSuggest;

  @override
  State<BranchEditPage> createState() => _BranchEditPageState();
}

class _BranchEditPageState extends State<BranchEditPage> {
  late final _label = TextEditingController(text: widget.branch.label ?? '');
  late final _address = TextEditingController(
    text: widget.branch.address ?? '',
  );
  late final _city = TextEditingController(text: widget.branch.city ?? '');
  late final _state = TextEditingController(text: widget.branch.state ?? '');
  // The dropdowns' lists; none (offline) = the two fields stay plain text.
  late final Future<List<AreaState>> _areas = context
      .read<PlacesController>()
      .areas()
      .catchError((Object _) => const <AreaState>[]);
  late final _latText = TextEditingController(
    text: widget.branch.lat?.toStringAsFixed(6) ?? '',
  );
  late final _lngText = TextEditingController(
    text: widget.branch.lng?.toStringAsFixed(6) ?? '',
  );
  // One door per role: the owner edits for everyone, a user for themselves (no switch to get wrong).
  late final BranchEditScope _scope = widget.canEditShared
      ? BranchEditScope.shared
      : BranchEditScope.personal;
  bool _pinChanged = false;
  bool _saving = false;
  bool _suggesting = false;
  bool _readingLink = false;
  final _mapsLink = TextEditingController();
  // Owner: search one map they pick.
  final _pinQuery = TextEditingController();
  String _pinSource = 'here';
  bool _searchingPin = false;
  List<PinHit>? _pinHits;
  final _added = <int>{}; // hits added as new branches (this search)
  int? _adding;
  String? _askedQuery; // the server's default words for the last map: not carried to another map

  /// Each map's default words (from the API), so the box is never empty to start with.
  Map<String, String> _pinDefaults = const {};
  BranchSuggestion? _suggestion;

  /// A draft photo picked as the restaurant's cover: set when the branch is saved.
  String? _photo;

  final _aiFields = <String>{};

  @override
  void initState() {
    super.initState();
    _latText.addListener(_coordsChanged);
    _lngText.addListener(_coordsChanged);
    if (widget.onSuggest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPinDefaults());
    }
  }

  /// A convenience: on failure the box just starts empty (the search still uses the same defaults).
  Future<void> _loadPinDefaults() async {
    try {
      final d = await context.read<PlacesController>().pinQueries(
        widget.branch.id,
      );
      if (!mounted) return;
      setState(() {
        _pinDefaults = d;
        _fillPinQuery();
      });
    } catch (_) {}
  }

  /// The chosen map's default words, unless the owner typed their own.
  void _fillPinQuery() {
    if (_pinQuery.text.isNotEmpty && _pinQuery.text != _askedQuery) return;
    final d = _pinDefaults[_pinSource];
    _pinQuery.text = d ?? '';
    _askedQuery = d;
  }

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _latText.dispose();
    _lngText.dispose();
    _mapsLink.dispose();
    _pinQuery.dispose();
    super.dispose();
  }

  void _coordsChanged() => setState(() => _pinChanged = true);

  double? get _typedLat => double.tryParse(_latText.text.trim());
  double? get _typedLng => double.tryParse(_lngText.text.trim());

  String? _latError(AppLocalizations l) {
    final text = _latText.text.trim();
    final other = _lngText.text.trim();
    if (text.isEmpty) return other.isEmpty ? null : l.branchCoordsInvalid;
    final value = double.tryParse(text);
    return value == null || value < 0.8 || value > 7.4
        ? l.branchCoordsInvalid
        : null;
  }

  String? _lngError(AppLocalizations l) {
    final text = _lngText.text.trim();
    final other = _latText.text.trim();
    if (text.isEmpty) return other.isEmpty ? null : l.branchCoordsInvalid;
    final value = double.tryParse(text);
    return value == null || value < 99.6 || value > 119.3
        ? l.branchCoordsInvalid
        : null;
  }

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => PinPickerPage(
          placeId: widget.placeId,
          branchId: widget.branch.id,
          initial: widget.branch.hasPin
              ? LatLng(widget.branch.lat!, widget.branch.lng!)
              : null,
          resultOnly: true,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _setPin(picked.latitude, picked.longitude);
  }

  void _setPin(double lat, double lng) {
    _latText.text = lat.toStringAsFixed(6);
    _lngText.text = lng.toStringAsFixed(6);
  }

  Future<void> _useMapsLink() async {
    final url = _mapsLink.text.trim();
    if (url.isEmpty || _readingLink) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _readingLink = true);
    try {
      final pin = await context.read<PlacesController>().pinFromMapsLink(url);
      if (!mounted) return;
      _setPin(pin.lat, pin.lng);
      setState(() => _aiFields.remove('location'));
      messenger.showSnackBar(SnackBar(content: Text(l.mapsLinkUsed)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _readingLink = false);
    }
  }

  Future<void> _searchPin() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _searchingPin = true);
    try {
      final r = await context.read<PlacesController>().searchPin(
        widget.branch.id,
        _pinSource,
        q: _text(_pinQuery),
      );
      if (!mounted) return;
      setState(() {
        // What was asked: the owner can change it and search again.
        _pinQuery.text = r.query;
        _askedQuery = r.query;
        _pinHits = r.hits;
        _added.clear();
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _searchingPin = false);
    }
  }

  /// "Use" on a map's result (a pin search hit or a draft's pin): its pin, address, town and state go into the form.
  /// No pin (a JAKIM outlet) = the text only; the owner pins it with another map.
  void _useFound(
    double? lat,
    double? lng, {
    String? address,
    String? city,
    String? state,
  }) {
    if (lat != null && lng != null) _setPin(lat, lng);
    setState(() {
      if (address case final a? when a.trim().isNotEmpty) _address.text = a;
      if (city case final c?) _city.text = c;
      if (state case final s?) _state.text = s;
      _aiFields.removeAll(['location', 'address', 'city', 'state']);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lat == null
              ? AppLocalizations.of(context).pinSearchUsedNoPin
              : AppLocalizations.of(context).pinSearchUsed,
        ),
      ),
    );
  }

  void _usePinHit(PinHit h) =>
      _useFound(h.lat, h.lng, address: h.address, city: h.city, state: h.state);

  /// Owner: the hit is another outlet of this shop: a new branch (the server names it shop + town; editable later).
  Future<void> _addBranch(int i) async {
    final h = _pinHits![i];
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = i);
    try {
      await context.read<PlacesController>().addSiblingBranch(
        widget.branch.id,
        address: h.address,
        city: h.city,
        state: h.state,
        lat: h.lat,
        lng: h.lng,
      );
      if (mounted) setState(() => _added.add(i));
      messenger.showSnackBar(SnackBar(content: Text(l.branchAdded)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _adding = null);
    }
  }

  /// Another map picked: nothing is asked yet (HERE and GrabMaps are metered); the owner presses Search.
  void _pickSource(String s) => setState(() {
    _pinSource = s;
    _pinHits = null;
    // Each map has its own best default (GrabMaps: the name alone); words the owner typed stay.
    _fillPinQuery();
  });

  Widget _pinSearch(AppLocalizations l, Notebook nb, TextTheme text) {
    final hits = _pinHits;
    final small = text.bodySmall?.copyWith(color: nb.inkSoft);
    return OwnerPanel(
      key: const ValueKey('pin-search-card'),
      icon: Icons.travel_explore,
      title: l.pinSearchTitle,
      children: [
        Wrap(
          spacing: spaceS,
          runSpacing: spaceS,
          children: [
            for (final s in const ['osm', 'here', 'grab', 'jakim'])
              ChoiceChip(
                key: ValueKey('pin-source-$s'),
                label: Text(_mapName(l, s)),
                selected: _pinSource == s,
                showCheckmark: false,
                onSelected: _searchingPin ? null : (_) => _pickSource(s),
              ),
          ],
        ),
        const SizedBox(height: spaceS),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _pinSource == 'here' || _pinSource == 'grab'
                  ? Icons.toll_outlined
                  : Icons.info_outline,
              size: 16,
              color: nb.inkSoft,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                switch (_pinSource) {
                  'osm' => l.pinSourceOsmHint,
                  'here' => l.pinSourceHereHint,
                  'jakim' => l.pinSourceJakimHint,
                  _ => l.pinSourceGrabHint,
                },
                key: const ValueKey('pin-source-hint'),
                style: small,
              ),
            ),
          ],
        ),
        const SizedBox(height: spaceM),
        TextField(
          key: const ValueKey('pin-search-query'),
          controller: _pinQuery,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchPin(),
          decoration: InputDecoration(
            labelText: l.pinSearchQuery,
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
        ),
        const SizedBox(height: spaceS),
        Align(
          alignment: Alignment.centerRight,
          child: BusyButton(
            key: const ValueKey('pin-search-go'),
            icon: Icons.search,
            label: l.pinSearchButton,
            busyLabel: l.ownerSearching,
            busy: _searchingPin,
            onPressed: _searchPin,
          ),
        ),
        if (hits != null && hits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: spaceS),
            child: Text(l.pinSearchNone, style: small),
          ),
        if (hits != null && hits.isNotEmpty) ...[
          const Divider(height: spaceL),
          Text(
            l.pinResultsTitle(hits.length, _mapName(l, _pinSource)),
            key: const ValueKey('pin-results-title'),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: spaceS),
          for (final (i, h) in hits.indexed) ...[
            if (i > 0) const SizedBox(height: spaceS),
            _HitCard(
              key: ValueKey('pin-hit-$i'),
              index: i,
              hit: h,
              added: _added.contains(i),
              adding: _adding == i,
              busy: _adding != null,
              onUse: () => _usePinHit(h),
              onAdd: () => _addBranch(i),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _suggest() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _suggesting = true);
    try {
      final suggestion = await widget.onSuggest!();
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _photo = null;
        _aiFields.clear();
        if (suggestion.draft.label case final label?) {
          _label.text = label;
          _aiFields.add('label');
        }
        if (suggestion.draft.address case final address?) {
          _address.text = address;
          _aiFields.add('address');
        }
        if (suggestion.draft.city case final city?) {
          _city.text = city;
          _aiFields.add('city');
        }
        if (suggestion.draft.state case final state?) {
          _state.text = state;
          _aiFields.add('state');
        }
        if (suggestion.draft.lat case final lat?
            when lat != widget.branch.lat) {
          _latText.text = lat.toStringAsFixed(6);
          _aiFields.add('location');
        }
        if (suggestion.draft.lng case final lng?
            when lng != widget.branch.lng) {
          _lngText.text = lng.toStringAsFixed(6);
          _aiFields.add('location');
        }
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  /// The owner takes ([use]) or leaves one field of the AI draft: the form gets the draft's value or the current one.
  void _pickDraft(String field, bool use) {
    final draft = _suggestion?.draft;
    if (draft == null) return;
    final b = widget.branch;
    String fixed(double? v) => v?.toStringAsFixed(6) ?? '';
    setState(() {
      switch (field) {
        case 'label':
          _label.text = (use ? draft.label : b.label) ?? '';
        case 'address':
          _address.text = (use ? draft.address : b.address) ?? '';
        case 'city':
          _city.text = (use ? draft.city : b.city) ?? '';
        case 'state':
          _state.text = (use ? draft.state : b.state) ?? '';
        case 'location':
          _latText.text = fixed(use ? draft.lat : b.lat);
          _lngText.text = fixed(use ? draft.lng : b.lng);
      }
      use ? _aiFields.add(field) : _aiFields.remove(field);
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final lat = _typedLat;
    final lng = _typedLng;
    final sendPin = _pinChanged && lat != null && lng != null;
    final places = context.read<PlacesController>();
    setState(() => _saving = true);
    try {
      await widget.onSave((
        label: _text(_label),
        address: _text(_address),
        city: _text(_city),
        state: _text(_state),
        lat: sendPin ? lat : null,
        lng: sendPin ? lng : null,
      ), _scope);
      // The branch is saved: a failed photo only says so (saving again would not help the photo).
      // The draft's photo is this outlet's own (Edit place can take it as the place's cover).
      if (_photo case final url?) {
        try {
          await places.setBranchCover(widget.branch.id, url);
        } catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(l.placeCoverFailed)));
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _scope == BranchEditScope.shared
                ? l.branchUpdated
                : l.branchUpdatedMine,
          ),
        ),
      );
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final latError = _latError(l);
    final lngError = _lngError(l);
    final canSave = !_saving && latError == null && lngError == null;
    final owner = widget.canEditShared;
    Widget tab(List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(
          _scope == BranchEditScope.shared ? l.editBranch : l.editBranchMine,
        ),
        bottom: _scope == BranchEditScope.shared
            ? OwnerStrip(l.ownerEditsEveryone)
            : null,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(spaceM),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              key: const ValueKey('branch-save'),
              tooltip: _scope == BranchEditScope.shared
                  ? l.saveForEveryone
                  : l.save,
              icon: const Icon(Icons.check),
              onPressed: canSave ? _save : null,
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        // The owner: Branch (the form), Find (AI draft, map search), Halal. A user: the form alone.
        child: EditTabs(
          sections: [
            DetailSection(
              id: 'branch-tab-details',
              label: l.branchTabDetails,
              rows: [
                // One row, not a lazy list: every field exists at once (a draft fills fields below the fold).
                tab([
                  if (owner) ...[
                    BranchCoverField(
                      branchId: widget.branch.id,
                      picked: _photo,
                    ),
                    const SizedBox(height: spaceM),
                  ] else ...[
                    // The owner's page says it in its strip; a user's edit is theirs alone.
                    Text(
                      l.branchPersonalOnly,
                      style: text.bodySmall?.copyWith(color: nb.inkSoft),
                    ),
                    const SizedBox(height: spaceS),
                  ],
                  const SizedBox(height: spaceS),
                  _field(
                    key: const ValueKey('branch-label'),
                    controller: _label,
                    label: l.branchLabel,
                    ai: _aiFields.contains('label'),
                  ),
                  _field(
                    key: const ValueKey('branch-address'),
                    controller: _address,
                    label: l.branchAddress,
                    ai: _aiFields.contains('address'),
                  ),
                  FutureBuilder(
                    future: _areas,
                    builder: (context, s) => _areaFields(l, s.data ?? const []),
                  ),
                  const SizedBox(height: spaceS),
                  _location(l, nb, text, latError, lngError),
                ]),
              ],
            ),
            if (owner && widget.onSuggest != null)
              DetailSection(
                id: 'branch-tab-find',
                label: l.branchTabFind,
                rows: [
                  tab([
                    _aiCard(l, nb, text),
                    const SizedBox(height: spaceM),
                    _pinSearch(l, nb, text),
                  ]),
                ],
              ),
            if (owner)
              DetailSection(
                id: 'branch-tab-halal',
                label: l.halalEditTitle,
                rows: [
                  tab([
                    BranchHalalEditor(
                      branch: widget.branch,
                      draft: _suggestion?.jakim,
                    ),
                  ]),
                ],
              ),
            if (owner)
              DetailSection(
                id: 'branch-tab-company',
                label: l.companyTab,
                rows: [
                  tab([BranchCompanyPanel(branch: widget.branch)]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Where the pin is now and where it came from, the coordinates, and the two ways to set them here.
  Widget _location(
    AppLocalizations l,
    Notebook nb,
    TextTheme text,
    String? latError,
    String? lngError,
  ) {
    final b = widget.branch;
    final status = _pinChanged
        ? l.pinNotSaved
        : !b.hasPin
        ? l.branchPinNone
        : b.pinSource == null
        ? null
        : l.pinFromSource(sourceName(l, b.pinSource!));
    return OwnerPanel(
      key: const ValueKey('branch-location'),
      icon: Icons.place_outlined,
      title: l.branchLocation,
      subtitle: status,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                key: const ValueKey('branch-lat'),
                controller: _latText,
                label: l.branchLatitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                errorText: latError,
                ai: _aiFields.contains('location'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                key: const ValueKey('branch-lng'),
                controller: _lngText,
                label: l.branchLongitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                errorText: lngError,
                ai: _aiFields.contains('location'),
              ),
            ),
          ],
        ),
        TextField(
          key: const ValueKey('branch-maps-link'),
          controller: _mapsLink,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _useMapsLink(),
          decoration: InputDecoration(
            labelText: l.mapsLinkLabel,
            helperText: l.mapsLinkHint,
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.link, size: 20),
            suffixIcon: _readingLink
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _useMapsLink,
                    child: Text(l.mapsLinkUse),
                  ),
          ),
        ),
        const SizedBox(height: spaceS),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _pickOnMap,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(l.setOnMap),
          ),
        ),
      ],
    );
  }

  /// The AI draft: what it does, the button; while it runs a progress line; then the draft to review.
  Widget _aiCard(AppLocalizations l, Notebook nb, TextTheme text) {
    final suggestion = _suggestion;
    return OwnerPanel(
      key: const ValueKey('ai-draft-card'),
      icon: Icons.auto_awesome,
      title: suggestion == null
          ? l.sourceAiDraft
          : suggestion.aiUsed
          ? l.aiDraftTitle
          : l.aiDraftFromMap,
      subtitle: suggestion == null && !_suggesting ? l.aiDraftCardHelp : null,
      children: [
        if (_suggesting)
          const _AiLoading()
        else if (suggestion != null)
          _DraftBanner(
            suggestion: suggestion,
            branch: widget.branch,
            used: _aiFields,
            onPick: _pickDraft,
            photo: _photo,
            onPhoto: (url) => setState(() => _photo = url),
            onUsePin: (c) => _useFound(c.lat, c.lng, address: c.address),
          ),
        if (!_suggesting)
          Align(
            alignment: Alignment.centerRight,
            child: AiButton(
              label: suggestion == null ? l.aiSuggest : l.aiSuggestAgain,
              onPressed: _saving ? null : _suggest,
            ),
          ),
      ],
    );
  }

  /// State first, then a town of that state, each picked from a searchable list; a town not listed is kept as
  /// typed ("Taman Melati").
  Widget _areaFields(AppLocalizations l, List<AreaState> areas) {
    final state = areas.where((s) => s.name == _state.text).firstOrNull;
    final towns = state?.towns ?? [for (final s in areas) ...s.towns];
    Widget field(
      String key,
      TextEditingController controller,
      String label,
      List<String> options,
      String ai,
      ValueChanged<String> onPicked,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PickerField(
        key: ValueKey(key),
        controller: controller,
        label: label,
        badge: _aiFields.contains(ai) ? const AiBadge() : null,
        options: options,
        allowTyped: true,
        onPicked: onPicked,
      ),
    );
    return Column(
      children: [
        field(
          'branch-state',
          _state,
          l.branchState,
          [for (final s in areas) s.name],
          'state',
          // Another state: a town of the old one no longer fits.
          (name) => setState(() {
            _aiFields.remove('state');
            final next = areas.where((s) => s.name == name).firstOrNull;
            if (next != null && !next.towns.contains(_city.text)) _city.clear();
          }),
        ),
        field(
          'branch-city',
          _city,
          l.branchCity,
          towns,
          'city',
          // A town picked before its state: the state follows.
          (town) => setState(() {
            _aiFields.remove('city');
            if (state != null) return;
            final of = areas.where((s) => s.towns.contains(town)).toList();
            if (of.length == 1) _state.text = of.single.name;
          }),
        ),
      ],
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? errorText,
    bool ai = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      decoration: InputDecoration(
        label: _fieldLabel(label, ai),
        errorText: errorText,
      ),
    ),
  );

  /// A field's label, with the "AI" badge beside it when the draft filled the field.
  Widget _fieldLabel(String label, bool ai) => ai
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            const AiBadge(),
          ],
        )
      : Text(label);
}

/// A provider or pin source as the owner reads it ("HERE", "OpenStreetMap"), not its code.
String sourceName(AppLocalizations l, String code) => switch (code) {
  'osm' || 'nominatim' || 'photon' || 'nominatim_reverse' => l.pinSearchOsm,
  'here' => l.pinSearchHere,
  'grab' => l.pinSearchGrab,
  'jakim' => l.pinSearchJakim,
  'overture' => 'Overture Maps',
  'web' => l.sourceWeb,
  'owner' => l.sourceOwner,
  'user' => l.sourceHandPins,
  'current' => l.sourceCurrentPin,
  'chain' || 'draft' => l.sourceAiDraft,
  _ when code.startsWith('draft:') =>
    '${l.sourceAiDraft} · ${sourceName(l, code.substring(6))}',
  _ => code,
};

String _mapName(AppLocalizations l, String s) => sourceName(l, s);

/// The AI draft, to review: what to check first, the fields it changed (each kept or dropped), the pins it found,
/// photos, JAKIM, and where it read.
class _DraftBanner extends StatelessWidget {
  const _DraftBanner({
    required this.suggestion,
    required this.branch,
    required this.used,
    required this.onPick,
    required this.onUsePin,
    required this.photo,
    required this.onPhoto,
  });

  final BranchSuggestion suggestion;

  /// The picked cover photo (null = none) and its change.
  final String? photo;
  final ValueChanged<String?> onPhoto;
  final Branch branch;

  /// The draft fields now in the form; [onPick] takes (field, use) from each row's tick box.
  final Set<String> used;
  final void Function(String field, bool use) onPick;
  final ValueChanged<PinCandidate> onUsePin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: nb.inkSoft);
    final heading = text.labelLarge?.copyWith(fontWeight: FontWeight.w700);
    final draft = suggestion.draft;
    final rows = <(String, String, String?, String?)>[
      ('label', l.branchLabel, branch.label, draft.label),
      ('address', l.branchAddress, branch.address, draft.address),
      ('city', l.branchCity, branch.city, draft.city),
      ('state', l.branchState, branch.state, draft.state),
      (
        'location',
        l.branchLocation,
        _coords(branch.lat, branch.lng),
        _coords(draft.lat, draft.lng),
      ),
    ].where((row) => row.$4 != null && row.$4!.trim().isNotEmpty).toList();
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: heading),
          ...children,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggestion.summary case final summary? when summary.isNotEmpty)
          Text(summary, style: text.bodyMedium),
        if (suggestion.warnings.isNotEmpty)
          Container(
            key: const ValueKey('draft-warnings'),
            margin: const EdgeInsets.only(top: spaceM),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: nb.kunyit.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: nb.kunyit),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: nb.ink),
                    const SizedBox(width: 6),
                    Text(l.aiDraftWarningsTitle, style: heading),
                  ],
                ),
                for (final w in suggestion.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• $w', style: text.bodySmall),
                  ),
              ],
            ),
          ),
        section(l.aiDraftFieldsTitle, [
          if (rows.isNotEmpty) ...[
            Text(l.aiDraftApplied, style: small),
            for (final row in rows)
              _DraftField(
                key: ValueKey('draft-${row.$1}'),
                label: row.$2,
                current: row.$3,
                suggested: row.$4!,
                use: used.contains(row.$1),
                onUse: (v) => onPick(row.$1, v),
              ),
          ] else
            Text(l.aiDraftNoFields, style: small),
          if (!suggestion.changed) Text(l.aiDraftNoInfo, style: small),
        ]),
        if (suggestion.candidates.length > 1)
          section(l.pinCandidatesTitle, [
            for (final c in suggestion.candidates)
              _PinRow(
                key: ValueKey('pin-${c.source}'),
                pin: c,
                onUse: onUsePin,
              ),
          ]),
        if (suggestion.photos.isNotEmpty)
          section(l.aiDraftPhotosTitle, [
            const SizedBox(height: spaceS),
            DraftPhotos(
              urls: suggestion.photos,
              picked: photo,
              onPick: onPhoto,
            ),
          ]),
        // JAKIM's rows are in the Halal tab; here only what the draft got from it.
        Padding(
          padding: const EdgeInsets.only(top: spaceM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, size: 16, color: nb.pandanDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  switch (suggestion.jakim) {
                    null => l.jakimDraftDown,
                    (rows: [], url: _, pick: _) => l.jakimDraftNone,
                    _ => l.jakimDraftSeeHalal,
                  },
                  key: const ValueKey('jakim-draft-status'),
                  style: small,
                ),
              ),
            ],
          ),
        ),
        if (suggestion.sources.isNotEmpty || suggestion.pages.isNotEmpty)
          section(l.aiDraftPagesTitle, [
            if (suggestion.sources.isNotEmpty)
              Text(
                l.aiDraftSources(
                  {for (final s in suggestion.sources) sourceName(l, s)}
                      .join(', '),
                ),
                style: small,
              ),
            if (suggestion.pages.isNotEmpty) ...[
              const SizedBox(height: 6),
              DraftSourceChips(sources: suggestion.pages),
            ],
          ]),
        const SizedBox(height: spaceS),
      ],
    );
  }
}

String? _coords(double? lat, double? lng) => lat == null || lng == null
    ? null
    : '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

/// One pin the draft found: whose, where, how far from the draft's, and Use.
class _PinRow extends StatelessWidget {
  const _PinRow({super.key, required this.pin, required this.onUse});

  final PinCandidate pin;
  final ValueChanged<PinCandidate> onUse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final m = pin.fromDraftM;
    return Padding(
      padding: const EdgeInsets.only(top: spaceS),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: nb.pandanDeep),
          const SizedBox(width: spaceS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceName(l, pin.source),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    _coords(pin.lat, pin.lng)!,
                    if (m != null && m > 0) l.pinCandidateFromDraft(m),
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(
                    color: nb.inkSoft,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => onUse(pin),
            child: Text(l.pinCandidateUse),
          ),
        ],
      ),
    );
  }
}

class _DraftField extends StatelessWidget {
  const _DraftField({
    super.key,
    required this.label,
    required this.current,
    required this.suggested,
    required this.use,
    required this.onUse,
  });

  final String label;
  final String? current;
  final String suggested;

  /// Ticked = the suggestion is in the form; unticked = the current value is kept.
  final bool use;
  final ValueChanged<bool> onUse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: nb.inkSoft);
    final same = current == suggested;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!same)
                SizedBox.square(
                  dimension: 28,
                  child: Checkbox(
                    value: use,
                    semanticLabel: l.aiDraftUseField(label),
                    onChanged: (v) => onUse(v ?? false),
                  ),
                ),
              // The texts give way (…) before the tick box and badge: large text never runs off the edge.
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              const AiBadge(),
              if (same)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '· ${l.aiDraftSame}',
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                  ),
                ),
            ],
          ),
          if (!same && current != null)
            Text(
              current!,
              style: small?.copyWith(decoration: TextDecoration.lineThrough),
            ),
          Text(
            suggested,
            style: text.bodySmall?.copyWith(
              color: nb.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiLoading extends StatelessWidget {
  const _AiLoading();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.aiSuggestBusy,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            minHeight: 3,
            color: nb.pandanDeep,
            backgroundColor: nb.line,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          l.aiSuggestDetail,
          style: text.bodySmall?.copyWith(color: nb.inkSoft),
        ),
      ],
    );
  }
}

/// One map result: name, address, town and state, the point; "Use" fills the form, "New branch" adds it as
/// another outlet (then marked Added).
class _HitCard extends StatelessWidget {
  const _HitCard({
    super.key,
    required this.index,
    required this.hit,
    required this.added,
    required this.adding,
    required this.busy,
    required this.onUse,
    required this.onAdd,
  });

  final int index;
  final PinHit hit;
  final bool added, adding, busy;
  final VoidCallback onUse, onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    const compact = Size(0, 40);
    final h = hit;
    final area = [h.city, h.state].nonNulls.join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nb.mist.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h.name case final name?)
            Text(name, style: text.labelMedium?.copyWith(color: nb.pandanDeep)),
          Text(
            h.address,
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (area.isNotEmpty)
            Text(area, style: text.bodyMedium?.copyWith(color: nb.inkSoft)),
          const SizedBox(height: 2),
          Text(
            h.lat == null || h.lng == null
                ? l.pinSearchNoPin
                : '${h.lat!.toStringAsFixed(5)}, ${h.lng!.toStringAsFixed(5)}',
            style: text.bodySmall?.copyWith(
              color: nb.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: spaceS),
          PanelActions(
            children: [
              TextButton.icon(
                key: ValueKey('pin-hit-add-$index'),
                style: TextButton.styleFrom(minimumSize: compact),
                onPressed: added || busy ? null : onAdd,
                icon: adding
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        added
                            ? Icons.check_circle_outline
                            : Icons.add_location_alt_outlined,
                        size: 18,
                      ),
                label: Text(added ? l.pinHitAdded : l.branchAddFromHit),
              ),
              FilledButton.icon(
                key: ValueKey('pin-hit-use-$index'),
                style: FilledButton.styleFrom(
                  minimumSize: compact,
                  padding: const EdgeInsets.symmetric(horizontal: spaceM),
                ),
                onPressed: onUse,
                icon: const Icon(Icons.check, size: 18),
                label: Text(l.pinCandidateUse),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
