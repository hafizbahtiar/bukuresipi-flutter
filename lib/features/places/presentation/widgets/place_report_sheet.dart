import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/report.dart';
import '../pages/pin_picker_page.dart';
import '../places_controller.dart';

/// A community report: pick the target/field, suggest a correction, and send it as a ticket for the owner.
class PlaceReportSheet extends StatefulWidget {
  const PlaceReportSheet({
    super.key,
    required this.subject,
    required this.onSubmit,
  });

  final ReportSubject subject;
  final Future<void> Function(ReportDraft draft) onSubmit;

  @override
  State<PlaceReportSheet> createState() => _PlaceReportSheetState();
}

class _PlaceReportSheetState extends State<PlaceReportSheet> {
  late bool _restaurant = widget.subject.branches.isEmpty;
  late String _branchId = widget.subject.branches.firstOrNull?.id ?? '';
  late ReportField _field = _restaurant
      ? ReportField.name
      : ReportField.location;
  final _value = TextEditingController();
  final _note = TextEditingController();
  final _mapsLink = TextEditingController();
  LatLng? _picked;
  String? _pickedFromLink; // the Google Maps link the pin came from: sent in the note, for the owner to open
  bool _readingLink = false;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    _mapsLink.dispose();
    super.dispose();
  }

  ReportBranch? get _branch =>
      widget.subject.branches.where((b) => b.id == _branchId).firstOrNull;

  List<ReportField> get _fields => _restaurant
      ? const [ReportField.name, ReportField.cuisine]
      : const [
          ReportField.location,
          ReportField.label,
          ReportField.address,
          ReportField.city,
          ReportField.state,
        ];

  String _fieldLabel(AppLocalizations l, ReportField field) => switch (field) {
    ReportField.location => l.reportFieldLocation,
    ReportField.label => l.reportFieldLabel,
    ReportField.address => l.reportFieldAddress,
    ReportField.city => l.reportFieldCity,
    ReportField.state => l.reportFieldState,
    ReportField.name => l.reportFieldName,
    ReportField.cuisine => l.reportFieldCuisine,
  };

  String? _current(AppLocalizations l) {
    if (_restaurant) {
      return _field == ReportField.name
          ? widget.subject.restaurantName
          : widget.subject.cuisine;
    }
    final b = _branch;
    if (b == null) return null;
    return switch (_field) {
      ReportField.location =>
        b.lat == null || b.lng == null
            ? l.reportNoLocation
            : '${b.lat!.toStringAsFixed(6)}, ${b.lng!.toStringAsFixed(6)}',
      ReportField.label => b.label,
      ReportField.address => b.address,
      ReportField.city => b.city,
      ReportField.state => b.state,
      _ => null,
    };
  }

  void _selectRestaurant() {
    setState(() {
      _restaurant = true;
      _field = ReportField.name;
      _picked = null;
      _value.clear();
    });
  }

  void _selectBranch(String id) {
    setState(() {
      _restaurant = false;
      _branchId = id;
      _field = ReportField.location;
      _picked = null;
      _value.clear();
    });
  }

  Future<void> _pickLocation() async {
    final branch = _branch;
    if (branch == null) return;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => PinPickerPage(
          placeId: widget.subject.placeId ?? '',
          branchId: branch.id,
          initial: branch.lat != null && branch.lng != null
              ? LatLng(branch.lat!, branch.lng!)
              : null,
          resultOnly: true,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _picked = picked;
        _pickedFromLink = null;
      });
    }
  }

  /// A Google Maps link the user copied from the place in Google Maps: the place's own pin (nothing saved yet).
  Future<void> _useMapsLink() async {
    final url = _mapsLink.text.trim();
    if (url.isEmpty || _readingLink) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _readingLink = true);
    try {
      final pin = await context.read<PlacesController>().pinFromMapsLink(url);
      if (!mounted) return;
      setState(() {
        _picked = LatLng(pin.lat, pin.lng);
        _pickedFromLink = url;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _readingLink = false);
    }
  }

  /// The user's note, with the Maps link the pin came from (the owner checks the place against it). Max 500.
  String? get _noteText {
    final parts = [
      _note.text.trim(),
      if (_field == ReportField.location && _pickedFromLink != null)
        _pickedFromLink!,
    ].where((s) => s.isNotEmpty);
    final note = parts.join('\n');
    if (note.isEmpty) return null;
    return note.length > 500 ? note.substring(0, 500) : note;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final location = _field == ReportField.location;
    final value = _value.text.trim();
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        ReportDraft(
          target: _restaurant ? ReportTarget.restaurant : ReportTarget.branch,
          targetId: _restaurant ? widget.subject.restaurantId : _branchId,
          field: _field,
          lat: location ? _picked?.latitude : null,
          lng: location ? _picked?.longitude : null,
          value: location || value.isEmpty ? null : value,
          note: _noteText,
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.reportSent)));
      navigator.pop();
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
    final location = _field == ReportField.location;
    final canSubmit =
        !_saving &&
        (location ? _picked != null : _value.text.trim().isNotEmpty);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 8),
              children: [
                Text(
                  l.reportTitle,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  l.reportTarget,
                  style: text.labelLarge?.copyWith(color: nb.inkSoft),
                ),
                const SizedBox(height: 6),
                NotebookSegmented<String>(
                  selected: _restaurant ? 'restaurant' : _branchId,
                  onChanged: (value) => value == 'restaurant'
                      ? _selectRestaurant()
                      : _selectBranch(value),
                  segments: [
                    NotebookSegment(
                      value: 'restaurant',
                      label: l.reportRestaurant,
                    ),
                    for (final b in widget.subject.branches)
                      NotebookSegment(value: b.id, label: b.title),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l.reportField,
                  style: text.labelLarge?.copyWith(color: nb.inkSoft),
                ),
                const SizedBox(height: 6),
                NotebookSegmented<ReportField>(
                  selected: _field,
                  onChanged: (field) => setState(() {
                    _field = field;
                    _picked = null;
                    _value.clear();
                  }),
                  segments: [
                    for (final field in _fields)
                      NotebookSegment(
                        value: field,
                        label: _fieldLabel(l, field),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${l.reportCurrent}: ${_current(l) ?? '—'}',
                  style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                ),
                const SizedBox(height: 8),
                if (location) ...[
                  Text(
                    _picked == null
                        ? l.reportChooseLocation
                        : '${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}',
                    style: text.bodyMedium?.copyWith(
                      color: nb.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextField(
                    key: const ValueKey('report-maps-link'),
                    controller: _mapsLink,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _useMapsLink(),
                    decoration: InputDecoration(
                      labelText: l.mapsLinkLabel,
                      helperText: l.reportMapsLinkHint,
                      helperMaxLines: 3,
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
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(l.reportSetLocation),
                    ),
                  ),
                ] else
                  TextField(
                    controller: _value,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l.reportSuggestedValue,
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l.reportNote),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l.report),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
