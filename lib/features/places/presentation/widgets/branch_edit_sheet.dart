import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../pages/pin_picker_page.dart';
import '../places_controller.dart';

typedef BranchEdit = ({
  String? label,
  String? address,
  String? city,
  String? state,
  double? lat,
  double? lng,
});

/// Edit for one branch. A normal user's edit is private to them; an owner can also choose to change the shared
/// branch. Moving a shared pin claims it as 'owner'; a text-only edit keeps the existing source.
class BranchEditSheet extends StatefulWidget {
  const BranchEditSheet({
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
  State<BranchEditSheet> createState() => _BranchEditSheetState();
}

class _BranchEditSheetState extends State<BranchEditSheet> {
  late final _label = TextEditingController(text: widget.branch.label ?? '');
  late final _address = TextEditingController(
    text: widget.branch.address ?? '',
  );
  late final _city = TextEditingController(text: widget.branch.city ?? '');
  late final _state = TextEditingController(text: widget.branch.state ?? '');
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
  BranchSuggestion? _suggestion;
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

  Future<void> _suggest() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _suggesting = true);
    try {
      final suggestion = await widget.onSuggest!();
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
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

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final lat = _typedLat;
    final lng = _typedLng;
    final sendPin = _pinChanged && lat != null && lng != null;
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _scope == BranchEditScope.shared
                        ? l.editBranch
                        : l.editBranchMine,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.canEditShared) ...[
                    Text(
                      l.branchScope,
                      style: text.bodySmall?.copyWith(color: nb.inkSoft),
                    ),
                    const SizedBox(height: 6),
                    NotebookSegmented<BranchEditScope>(
                      selected: _scope,
                      onChanged: (scope) => setState(() => _scope = scope),
                      segments: [
                        NotebookSegment(
                          value: BranchEditScope.personal,
                          label: l.branchScopeMine,
                        ),
                        NotebookSegment(
                          value: BranchEditScope.shared,
                          label: l.branchScopeEveryone,
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
                          onUsePin: (c) => _setPin(c.lat, c.lng),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _saving ? null : _suggest,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            _suggestion == null
                                ? l.aiSuggest
                                : l.aiSuggestAgain,
                          ),
                        ),
                      ),
                    ],
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
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          key: const ValueKey('branch-city'),
                          controller: _city,
                          label: l.branchCity,
                          ai: _aiFields.contains('city'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          key: const ValueKey('branch-state'),
                          controller: _state,
                          label: l.branchState,
                          ai: _aiFields.contains('state'),
                        ),
                      ),
                    ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l.save),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        labelText: label,
        errorText: errorText,
        suffixIcon: ai
            ? const Padding(
                padding: EdgeInsets.only(right: 6),
                child: _AiBadge(),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 0),
      ),
    ),
  );
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({
    required this.suggestion,
    required this.branch,
    required this.onUsePin,
  });

  final BranchSuggestion suggestion;
  final Branch branch;
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
    final rows = <(String, String?, String?)>[
      (l.branchLabel, branch.label, draft.label),
      (l.branchAddress, branch.address, draft.address),
      (l.branchCity, branch.city, draft.city),
      (l.branchState, branch.state, draft.state),
      (
        l.branchLocation,
        _coords(branch.lat, branch.lng),
        _coords(draft.lat, draft.lng),
      ),
    ].where((row) => row.$3 != null && row.$3!.trim().isNotEmpty).toList();
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
              _DraftField(label: row.$1, current: row.$2, suggested: row.$3!),
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
          for (final warning in suggestion.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $warning', style: small),
            ),
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
    required this.label,
    required this.current,
    required this.suggested,
  });

  final String label;
  final String? current;
  final String suggested;

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
              Text(
                label,
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              const _AiBadge(),
              if (same)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text('· ${l.aiDraftSame}', style: small),
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

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: nb.mist,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: nb.pandanDeep.withValues(alpha: 0.35)),
      ),
      child: Text(
        'AI',
        style: nb.hand.copyWith(fontSize: 15, height: 1, color: nb.pandanDeep),
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
