import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/draft_photos.dart';

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

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

typedef BranchEdit = ({
  String? label,
  String? address,
  String? city,
  String? state,
  double? lat,
  double? lng,
});

/// Opens the branch edit page; true = saved.
Future<bool?> showBranchEdit(
  BuildContext context, {
  required WidgetBuilder builder,
}) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: builder));

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
  late BranchEditScope _scope = widget.canEditShared
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
  String? _askedQuery; // the server's default words for the last map: not carried to another map
  BranchSuggestion? _suggestion;

  /// A draft photo picked as the restaurant's cover: set when the branch is saved.
  String? _photo;
  final _labelAnchor = GlobalKey();
  final _aiFields = <String>{};

  @override
  void initState() {
    super.initState();
    _latText.addListener(_coordsChanged);
    _lngText.addListener(_coordsChanged);
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
      });
      if (r.hits.isNotEmpty) unawaited(_showPinHits());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _searchingPin = false);
    }
  }

  /// "Use" on a map's result (a pin search hit or a draft's pin): its pin, address, town and state go into the form.
  void _useFound(
    double lat,
    double lng, {
    String? address,
    String? city,
    String? state,
  }) {
    _setPin(lat, lng);
    setState(() {
      if (address case final a? when a.trim().isNotEmpty) _address.text = a;
      if (city case final c?) _city.text = c;
      if (state case final s?) _state.text = s;
      _aiFields.removeAll(['location', 'address', 'city', 'state']);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).pinSearchUsed)),
    );
  }

  void _usePinHit(PinHit h) =>
      _useFound(h.lat, h.lng, address: h.address, city: h.city, state: h.state);

  /// The last search's results in a sheet; "Use" fills the form. Closed, the form keeps a button to open it again.
  Future<void> _showPinHits() async {
    final hits = _pinHits;
    if (hits == null || hits.isEmpty) return;
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final map = switch (_pinSource) {
      'osm' => l.pinSearchOsm,
      'here' => l.pinSearchHere,
      _ => l.pinSearchGrab,
    };
    final picked = await showModalBottomSheet<PinHit>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
          ),
          child: _PinHitsSheet(
            title: l.pinResultsTitle(hits.length, map),
            query: _pinQuery.text,
            hits: hits,
            onAdd: _addBranch,
          ),
        ),
      ),
    );
    if (picked != null && mounted) _usePinHit(picked);
  }

  /// Owner: the hit is another outlet of this shop: a new branch (the server names it shop + town; editable later).
  /// true = added.
  Future<bool> _addBranch(PinHit h) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<PlacesController>().addSiblingBranch(
        widget.branch.id,
        address: h.address,
        city: h.city,
        state: h.state,
        lat: h.lat,
        lng: h.lng,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.branchAdded)));
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      return false;
    }
  }

  Widget _pinSearch(AppLocalizations l, Notebook nb, TextTheme text) {
    final hits = _pinHits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          l.pinSearchTitle,
          style: text.labelLarge?.copyWith(color: nb.inkSoft),
        ),
        Text(
          l.pinSearchHelp,
          style: text.bodySmall?.copyWith(color: nb.inkSoft),
        ),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          showSelectedIcon: false,
          selected: {_pinSource},
          // Picking a map asks it at once: the choice is the search.
          onSelectionChanged: (picked) {
            final s = picked.first;
            setState(() {
              _pinSource = s;
              _pinHits = null;
              // Each map has its own best default (GrabMaps: the name alone); words the owner typed stay.
              if (_pinQuery.text == _askedQuery) _pinQuery.clear();
            });
            _searchPin();
          },
          segments: [
            ButtonSegment(value: 'osm', label: Text(l.pinSearchOsm)),
            ButtonSegment(value: 'here', label: Text(l.pinSearchHere)),
            ButtonSegment(value: 'grab', label: Text(l.pinSearchGrab)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('pin-search-query'),
          controller: _pinQuery,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchPin(),
          decoration: InputDecoration(
            labelText: l.pinSearchQuery,
            suffixIcon: _searchingPin
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    key: const ValueKey('pin-search-go'),
                    onPressed: _searchPin,
                    child: Text(l.pinSearchButton),
                  ),
          ),
        ),
        if (hits != null && hits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.pinSearchNone,
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
          ),
        if (hits != null && hits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: spaceS),
            child: OutlinedButton.icon(
              key: const ValueKey('pin-search-results'),
              onPressed: _showPinHits,
              icon: const Icon(Icons.list_alt_outlined, size: 18),
              label: Text(l.pinResultsShow(hits.length)),
            ),
          ),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final anchor = _labelAnchor.currentContext;
        if (anchor == null || !mounted) return;
        Scrollable.ensureVisible(
          anchor,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
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
      if ((_photo, _suggestion?.placeId) case (final url?, final id?)) {
        try {
          await places.setRestaurantCoverUrl(id, url);
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(
          _scope == BranchEditScope.shared ? l.editBranch : l.editBranchMine,
        ),
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
              tooltip: l.save,
              icon: const Icon(Icons.check),
              onPressed: canSave ? _save : null,
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        // Not a lazy list: every field exists at once (a draft fills fields below the fold).
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.canEditShared) ...[
                Text(
                  l.branchScope,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
                const SizedBox(height: 6),
                SegmentedButton<BranchEditScope>(
                  showSelectedIcon: false,
                  selected: {_scope},
                  onSelectionChanged: (picked) =>
                      setState(() => _scope = picked.first),
                  segments: [
                    ButtonSegment(
                      value: BranchEditScope.personal,
                      label: Text(l.branchScopeMine),
                    ),
                    ButtonSegment(
                      value: BranchEditScope.shared,
                      label: Text(l.branchScopeEveryone),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _scope == BranchEditScope.shared
                    ? l.branchShared
                    : l.branchPersonalOnly,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
              const SizedBox(height: 8),
              if (widget.canEditShared && widget.onSuggest != null) ...[
                if (_suggesting)
                  const _AiLoading()
                else ...[
                  if (_suggestion case final suggestion?)
                    _DraftBanner(
                      suggestion: suggestion,
                      branch: widget.branch,
                      used: _aiFields,
                      onPick: _pickDraft,
                      photo: _photo,
                      onPhoto: (url) => setState(() => _photo = url),
                      onUsePin: (c) =>
                          _useFound(c.lat, c.lng, address: c.address),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AiButton(
                      label: _suggestion == null
                          ? l.aiSuggest
                          : l.aiSuggestAgain,
                      onPressed: _saving ? null : _suggest,
                    ),
                  ),
                ],
                _pinSearch(l, nb, text),
              ],
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _labelAnchor,
                child: _field(
                  key: const ValueKey('branch-label'),
                  controller: _label,
                  label: l.branchLabel,
                  ai: _aiFields.contains('label'),
                ),
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
              const SizedBox(height: 8),
              Text(
                l.branchLocation,
                style: text.labelLarge?.copyWith(color: nb.inkSoft),
              ),
              const SizedBox(height: 6),
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
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: _useMapsLink,
                          child: Text(l.mapsLinkUse),
                        ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pickOnMap,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(l.setOnMap),
                ),
              ),
            ],
          ),
        ),
      ),
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

  String? _coords(double? lat, double? lng) => lat == null || lng == null
      ? null
      : '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: nb.inkSoft);
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nb.mist,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: nb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: nb.pandanDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  suggestion.aiUsed ? l.aiDraftTitle : l.aiDraftFromMap,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (suggestion.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.aiDraftSources(suggestion.sources.join(', ')),
                style: small,
              ),
            ),
          if (suggestion.summary case final summary? when summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(summary, style: small),
            ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 4),
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
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.aiDraftNoFields, style: small),
            ),
          if (!suggestion.changed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.aiDraftNoInfo, style: small),
            ),
          if (suggestion.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            DraftPhotos(
              urls: suggestion.photos,
              picked: photo,
              onPick: onPhoto,
            ),
          ],
          for (final warning in suggestion.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: nb.margin),
                  const SizedBox(width: 6),
                  Expanded(child: Text(warning, style: small)),
                ],
              ),
            ),
          if (suggestion.pages.isNotEmpty) ...[
            const SizedBox(height: 8),
            DraftSourceChips(sources: suggestion.pages),
          ],
          if (suggestion.candidates.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              l.pinCandidatesTitle,
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            for (final c in suggestion.candidates)
              Row(
                key: ValueKey('pin-${c.source}'),
                children: [
                  Expanded(
                    child: Text(
                      [
                        c.source,
                        _coords(c.lat, c.lng),
                        if (c.fromDraftM case final m? when m > 0) '$m m',
                      ].join(' · '),
                      style: small,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onUsePin(c),
                    child: Text(l.pinCandidateUse),
                  ),
                ],
              ),
          ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nb.mist,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: nb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: nb.pandanDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.aiSuggestBusy,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
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
      ),
    );
  }
}

/// A map's results: each hit as a card (address, town and state, the point), with its two actions:
/// "Use" fills the form and closes the sheet; "New branch" adds it as another outlet and stays (marked Added).
class _PinHitsSheet extends StatefulWidget {
  const _PinHitsSheet({
    required this.title,
    required this.query,
    required this.hits,
    required this.onAdd,
  });

  final String title;
  final String query;
  final List<PinHit> hits;
  final Future<bool> Function(PinHit) onAdd;

  @override
  State<_PinHitsSheet> createState() => _PinHitsSheetState();
}

class _PinHitsSheetState extends State<_PinHitsSheet> {
  final _added = <int>{};
  int? _adding;

  Future<void> _add(int i) async {
    setState(() => _adding = i);
    final ok = await widget.onAdd(widget.hits[i]);
    if (mounted) {
      setState(() {
        _adding = null;
        if (ok) _added.add(i);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    const compact = Size(0, 40);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: text.titleMedium),
              if (widget.query.isNotEmpty)
                Text(
                  '“${widget.query}”',
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceM),
            itemCount: widget.hits.length,
            separatorBuilder: (_, _) => const SizedBox(height: spaceS),
            itemBuilder: (context, i) {
              final h = widget.hits[i];
              final area = [h.city, h.state].nonNulls.join(', ');
              final added = _added.contains(i);
              return Container(
                key: ValueKey('pin-hit-$i'),
                padding: const EdgeInsets.all(spaceM - 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: nb.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: nb.mist,
                          child: Icon(
                            Icons.place_outlined,
                            size: 20,
                            color: nb.pandanDeep,
                          ),
                        ),
                        const SizedBox(width: spaceM - 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.address,
                                style: text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (area.isNotEmpty)
                                Text(
                                  area,
                                  style: text.bodyMedium?.copyWith(
                                    color: nb.inkSoft,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                '${h.lat.toStringAsFixed(5)}, ${h.lng.toStringAsFixed(5)}',
                                style: text.bodySmall?.copyWith(
                                  color: nb.inkSoft,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: spaceS),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          key: ValueKey('pin-hit-add-$i'),
                          style: TextButton.styleFrom(minimumSize: compact),
                          onPressed: added || _adding != null
                              ? null
                              : () => _add(i),
                          icon: _adding == i
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  added
                                      ? Icons.check_circle_outline
                                      : Icons.add_location_alt_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            added ? l.pinHitAdded : l.branchAddFromHit,
                          ),
                        ),
                        const SizedBox(width: spaceS),
                        FilledButton.icon(
                          key: ValueKey('pin-hit-use-$i'),
                          style: FilledButton.styleFrom(
                            minimumSize: compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: spaceM,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, h),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(l.pinCandidateUse),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
