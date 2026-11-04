import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../pages/pin_picker_page.dart';

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
  });

  final String placeId;
  final Branch branch;
  final bool canEditShared;
  final Future<void> Function(BranchEdit edit, BranchEditScope scope) onSave;

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
    _latText.text = picked.latitude.toStringAsFixed(6);
    _lngText.text = picked.longitude.toStringAsFixed(6);
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
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l.branchScopeMine),
                          selected: _scope == BranchEditScope.personal,
                          onSelected: (_) =>
                              setState(() => _scope = BranchEditScope.personal),
                        ),
                        ChoiceChip(
                          label: Text(l.branchScopeEveryone),
                          selected: _scope == BranchEditScope.shared,
                          onSelected: (_) =>
                              setState(() => _scope = BranchEditScope.shared),
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
                  const SizedBox(height: 16),
                  _field(
                    key: const ValueKey('branch-label'),
                    controller: _label,
                    label: l.branchLabel,
                  ),
                  _field(
                    key: const ValueKey('branch-address'),
                    controller: _address,
                    label: l.branchAddress,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          key: const ValueKey('branch-city'),
                          controller: _city,
                          label: l.branchCity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          key: const ValueKey('branch-state'),
                          controller: _state,
                          label: l.branchState,
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
                        ),
                      ),
                    ],
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      decoration: InputDecoration(labelText: label, errorText: errorText),
    ),
  );
}
