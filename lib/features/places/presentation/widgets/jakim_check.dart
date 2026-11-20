import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/widgets/base.dart'
    show MenuAction, showActionSheet, showBasePicker;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import 'owner_panel.dart';

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String _day(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);

/// The book's copy of a branch's certificate (fresh after a save), else the one the page opened with.
HalalCert? _certOf(BuildContext context, Branch branch) =>
    context.select<PlacesController, HalalCert?>(
      (c) =>
          c.places
              .expand((p) => p.branches)
              .where((b) => b.id == branch.id)
              .firstOrNull
              ?.halalCert ??
          branch.halalCert,
    );

/// A spinner the size of an icon, for a field's suffix or a row's action while it works.
const _spin = Padding(
  padding: EdgeInsets.all(14),
  child: SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  ),
);

// ---------------------------------------------------------------------------------------------------------------
// Edit branch > Halal

/// Owner, Edit branch > Halal: this outlet's JAKIM certificate, then "Find on JAKIM": Check JAKIM (by the place's
/// name and postcode; a match is saved) or a search in the owner's own words (rows listed, one is used). The search
/// box starts with the certificate's premise as JAKIM lists it (else the AI draft's pick), never our name. An AI
/// draft's rows ([draft]) show as the first result.
class BranchHalalEditor extends StatefulWidget {
  const BranchHalalEditor({super.key, required this.branch, this.draft});

  final Branch branch;
  final ({String url, List<JakimRow> rows, int? pick})? draft;

  @override
  State<BranchHalalEditor> createState() => _BranchHalalEditorState();
}

class _BranchHalalEditorState extends State<BranchHalalEditor> {
  late final _query = TextEditingController(
    text:
        widget.branch.halalCert?.premise ??
        switch (widget.draft) {
          (rows: final rows, pick: final p?, url: _) => rows[p].premise,
          _ => '',
        },
  );

  bool _checking = false;
  bool _searching = false;

  /// The row being saved (its button spins), or -1 for Remove.
  int? _saving;

  /// The last answer: a check, a search ([_asked] = its words) or the AI draft. null = nothing asked yet.
  JakimCheck? _result;
  String? _asked;

  /// What the stored certificate says beyond the book (premise address, brand, how it was linked).
  BranchCompany? _info;

  bool get _busy => _checking || _searching || _saving != null;

  @override
  void initState() {
    super.initState();
    _fromDraft();
    if (widget.branch.halalCert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadInfo());
      });
    }
  }

  @override
  void didUpdateWidget(BranchHalalEditor old) {
    super.didUpdateWidget(old);
    if (widget.draft != old.draft) _fromDraft();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _fromDraft() {
    if (widget.draft case final d?) {
      _result = (status: 'draft', url: d.url, rows: d.rows, pick: d.pick);
      if (_query.text.isEmpty && d.pick != null) {
        _query.text = d.rows[d.pick!].premise;
      }
    }
  }

  Future<void> _loadInfo() async {
    try {
      final r = await context.read<PlacesController>().branchCompany(
        widget.branch.id,
      );
      if (mounted) setState(() => _info = r);
    } catch (_) {
      // Extra lines only: the certificate itself shows from the book.
    }
  }

  /// Runs [work] with [mark] on (its button spins), then reads the certificate's extra lines again.
  Future<void> _run(
    void Function(bool on) mark,
    Future<void> Function(PlacesController) work,
  ) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    FocusScope.of(context).unfocus();
    setState(() => mark(true));
    try {
      await work(places);
      if (mounted) unawaited(_loadInfo());
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => mark(false));
    }
  }

  Future<void> _check() => _run((on) => _checking = on, (places) async {
    final r = await places.checkHalalBranch(widget.branch.id);
    if (!mounted) return;
    setState(() {
      _result = r;
      _asked = null;
    });
  });

  Future<void> _search() {
    final q = _query.text.trim();
    if (q.length < 2) return Future.value();
    return _run((on) => _searching = on, (places) async {
      final r = await places.checkHalalBranch(widget.branch.id, q: q);
      if (!mounted) return;
      setState(() {
        _result = r;
        _asked = q;
      });
    });
  }

  Future<void> _use(int i, JakimRow row, String url) =>
      _run((on) => _saving = on ? i : null, (places) async {
        await places.setHalalCert(widget.branch.id, row, url);
        if (mounted) {
          _query.text = row.premise;
          _snack(context, AppLocalizations.of(context).jakimCertSaved);
        }
      });

  Future<void> _remove() => _run(
    (on) => _saving = on ? -1 : null,
    (places) => places.setHalalCert(widget.branch.id, null, ''),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cert = _certOf(context, widget.branch);
    // A read from before a re-pair is not this certificate's.
    final info = _info?.premise == cert?.premise ? _info : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _certPanel(l, cert, info),
        const SizedBox(height: spaceM),
        _findPanel(l, cert),
      ],
    );
  }

  Widget _certPanel(AppLocalizations l, HalalCert? cert, BranchCompany? info) {
    final nb = Notebook.of(context);
    final expired = cert?.expiredAt(DateTime.now()) ?? false;
    return OwnerPanel(
      key: const ValueKey('branch-cert'),
      icon: Icons.verified_outlined,
      title: l.halalCertTitle,
      trailing: PanelChip(
        key: const ValueKey('branch-cert-status'),
        label: cert == null
            ? l.certStatusNone
            : expired
            ? l.certStatusExpired
            : l.certStatusValid,
        tone: cert == null
            ? PanelTone.info
            : expired
            ? PanelTone.error
            : PanelTone.success,
      ),
      children: [
        if (cert == null)
          Text(
            l.halalEditNoCert,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: nb.inkSoft),
          )
        else ...[
          InfoRow(label: l.certPremise, value: cert.premise, strong: true),
          InfoRow(
            key: const ValueKey('cert-address'),
            label: l.companyPremiseAddress,
            value: info?.premiseAddress,
          ),
          InfoRow(
            key: const ValueKey('cert-brand'),
            label: l.companyBrand,
            value: info?.brand,
          ),
          InfoRow(
            label: l.certValidUntil,
            value: _day(context, cert.expiresOn),
          ),
          InfoRow(
            label: l.certChecked,
            value: _day(context, cert.checkedAt.toLocal()),
          ),
          if (info != null)
            InfoRow(
              label: l.certLinked,
              value: info.source == 'owner'
                  ? l.certSourceOwner
                  : l.certSourceAuto,
            ),
          const SizedBox(height: spaceM),
          PanelActions(
            children: [
              BusyButton(
                key: const ValueKey('branch-halal-remove'),
                kind: BusyButtonKind.danger,
                icon: Icons.link_off,
                label: l.halalCertRemove,
                busyLabel: l.ownerSaving,
                busy: _saving == -1,
                onPressed: _busy ? null : _remove,
              ),
              BusyButton(
                kind: BusyButtonKind.outlined,
                icon: Icons.open_in_new,
                label: l.halalCertOpen,
                busyLabel: l.halalCertOpen,
                busy: false,
                onPressed: () =>
                    openLink(context, cert.url, failed: l.openFailed),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _findPanel(AppLocalizations l, HalalCert? cert) {
    final result = _result;
    final name = widget.branch.label ?? widget.branch.where ?? '-';
    return OwnerPanel(
      key: const ValueKey('branch-halal-find'),
      icon: Icons.manage_search,
      title: l.halalFindTitle,
      subtitle: l.halalFindHelp,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: BusyButton(
            key: const ValueKey('branch-halal-check'),
            icon: Icons.fact_check_outlined,
            label: l.jakimCheck,
            busyLabel: l.jakimChecking,
            busy: _checking,
            onPressed: _busy ? null : _check,
          ),
        ),
        const SizedBox(height: spaceL),
        TextField(
          key: const ValueKey('branch-halal-query'),
          controller: _query,
          enabled: !_busy,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: l.jakimQuery,
            helperText: l.jakimQueryHelp,
            helperMaxLines: 5,
            suffixIcon: _searching
                ? _spin
                : IconButton(
                    key: const ValueKey('branch-halal-search'),
                    tooltip: l.jakimSearch,
                    onPressed: _busy ? null : _search,
                    icon: const Icon(Icons.search),
                  ),
          ),
        ),
        if (_searching) ...[
          const SizedBox(height: spaceM),
          PanelLoading(text: l.jakimSearching),
        ] else if (_checking)
          const SizedBox.shrink()
        else if (result != null) ...[
          const SizedBox(height: spaceM),
          PanelNotice(
            key: const ValueKey('branch-halal-status'),
            tone: switch (result.status) {
              'found' => PanelTone.success,
              'unavailable' => PanelTone.error,
              _ when result.rows.isEmpty => PanelTone.warning,
              _ => PanelTone.info,
            },
            text: switch (result.status) {
              'found' => l.jakimCheckFound(name),
              'unavailable' => l.jakimCheckDown,
              'listed' => l.jakimListed(result.rows.length, _asked ?? ''),
              _ when result.rows.isEmpty => l.jakimCheckNone(name),
              _ => l.jakimChooseTitle(name),
            },
          ),
          for (final (i, r) in result.rows.indexed) ...[
            const SizedBox(height: spaceS),
            _RowCard(
              key: ValueKey('jakim-row-$i'),
              row: r,
              aiPick: result.status == 'draft' && i == result.pick,
              action: cert?.premise == r.premise
                  ? PanelChip(
                      key: ValueKey('jakim-linked-$i'),
                      label: l.jakimLinked,
                      tone: PanelTone.success,
                    )
                  : BusyButton(
                      key: ValueKey('jakim-save-$i'),
                      icon: Icons.link,
                      label: l.jakimUseRow,
                      busyLabel: l.ownerSaving,
                      busy: _saving == i,
                      onPressed: _busy || result.url == null
                          ? null
                          : () => _use(i, r, result.url!),
                    ),
            ),
          ],
          if (result.status == 'draft' && result.rows.isNotEmpty) ...[
            const SizedBox(height: spaceS),
            Text(
              l.jakimDraftNote,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Notebook.of(context).inkSoft),
            ),
          ],
        ],
      ],
    );
  }
}

/// One row of JAKIM's directory, as a small card: premise (with a ⋮ [menu] of the less likely actions), address
/// and expiry, a note, then its one main action at the bottom right.
class _RowCard extends StatelessWidget {
  const _RowCard({
    super.key,
    required this.row,
    this.aiPick = false,
    this.note,
    required this.action,
    this.menu,
  });

  final JakimRow row;
  final bool aiPick;

  /// A line under the address (paired with / same postcode as a branch).
  final Widget? note;
  final Widget action;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  // Level with the menu button's icon.
                  padding: EdgeInsets.only(top: menu == null ? 0 : 8),
                  child: Text(
                    row.premise,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (menu case final m?) ...[const SizedBox(width: 4), m],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.jakimDraftRow(row.address, _day(context, row.expiresOn)),
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          if (aiPick) ...[
            const SizedBox(height: 6),
            AiBadge(label: l.jakimAiPick),
          ],
          if (note case final n?) ...[const SizedBox(height: 6), n],
          const SizedBox(height: spaceS),
          Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Edit branch > Company

/// Owner, Edit branch > Company: the company behind this branch's certificate (JAKIM's company page) and "Get
/// company info again" (read now; a certificate paired by hand is checked first). Reads again when the certificate
/// changes on the Halal tab.
class BranchCompanyPanel extends StatefulWidget {
  const BranchCompanyPanel({super.key, required this.branch});

  final Branch branch;

  @override
  State<BranchCompanyPanel> createState() => _BranchCompanyPanelState();
}

class _BranchCompanyPanelState extends State<BranchCompanyPanel> {
  BranchCompany? _info;
  bool _refreshing = false, _copying = false;

  /// "Same company as…" was used: the branch it came from (said under the company).
  String? _copiedFrom;

  /// The answer of the last "Get company info again" (ok | unavailable | none).
  String? _status;

  /// The certificate the shown info was read for: another one (a save on the Halal tab) = read again.
  String? _readFor;

  Future<void> _load({bool refresh = false}) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    if (refresh) setState(() => _refreshing = true);
    try {
      final r = await places.branchCompany(widget.branch.id, refresh: refresh);
      if (mounted) {
        setState(() {
          _info = r;
          _status = refresh ? r.status : null;
          _copiedFrom = null;
        });
      }
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted && refresh) setState(() => _refreshing = false);
    }
  }

  /// "Same company as…": the place's other branches with a company; the owner picks one (never automatic: a
  /// franchise outlet is often another company).
  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    setState(() => _copying = true);
    try {
      // One row per company (branches of one company share it): the first branch names where it comes from.
      final from = <String, _Row>{
        for (final b in (await places.placeCompanies(_info!.placeId!)).reversed)
          if (b.branchId != widget.branch.id && b.info.company != null)
            b.info.company!.code: b,
      }.values.toList().reversed.toList();
      if (!mounted) return;
      if (from.isEmpty) {
        _snack(context, l.companySameNone);
        return;
      }
      setState(() => _copying = false);
      final pick = await showBasePicker<_Row>(
        context,
        title: l.companySameTitle,
        options: from,
        selected: null,
        // The company is what is picked; its branch under it.
        label: (b) =>
            '${b.info.company!.name}\n${b.label ?? b.info.premise ?? '-'}',
        search: from.length > 8,
      );
      if (pick == null || !mounted) return;
      setState(() => _copying = true);
      final r = await places.copyBranchCompany(widget.branch.id, pick.branchId);
      if (mounted) {
        setState(() {
          _info = r;
          _status = null;
          _copiedFrom = pick.label ?? pick.info.premise ?? '-';
        });
      }
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final cert = _certOf(context, widget.branch);
    if (cert != null && cert.premise != _readFor) {
      _readFor = cert.premise;
      _info = null;
      _status = null;
      _copiedFrom = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
    final c = _info?.company;
    return OwnerPanel(
      key: const ValueKey('branch-company'),
      icon: Icons.business_outlined,
      title: l.companyTitle,
      subtitle: l.companyOwnerOnly,
      children: [
        if (cert == null)
          PanelNotice(text: l.companyNeedsCert, tone: PanelTone.info)
        else if (_info == null)
          PanelLoading(text: l.ownerLoading)
        else ...[
          if (c != null)
            CompanyDetails(company: c)
          else
            Text(
              l.companyNone,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: nb.inkSoft),
            ),
          if (_status case final s?) ...[
            const SizedBox(height: spaceM),
            PanelNotice(
              key: const ValueKey('branch-company-status'),
              text: switch (s) {
                'ok' => l.companyUpdated,
                'unavailable' => l.jakimCheckDown,
                _ => l.companyNone,
              },
              tone: switch (s) {
                'ok' => PanelTone.success,
                'unavailable' => PanelTone.error,
                _ => PanelTone.warning,
              },
            ),
          ],
          if (_copiedFrom case final from?) ...[
            const SizedBox(height: spaceM),
            PanelNotice(
              key: const ValueKey('branch-company-copied'),
              text: l.companySameDone(from),
              tone: PanelTone.success,
            ),
          ],
          const SizedBox(height: spaceM),
          PanelActions(
            children: [
              if (c == null && _info?.placeId != null && !_refreshing)
                BusyButton(
                  key: const ValueKey('branch-company-same'),
                  kind: BusyButtonKind.outlined,
                  icon: Icons.business_outlined,
                  label: l.companySame,
                  busyLabel: l.ownerLoading,
                  busy: _copying,
                  onPressed: _copy,
                ),
              if (!_copying)
                BusyButton(
                  key: const ValueKey('branch-company-refresh'),
                  kind: BusyButtonKind.outlined,
                  icon: Icons.refresh,
                  label: l.companyRefresh,
                  busyLabel: l.companyReading,
                  busy: _refreshing,
                  onPressed: () => _load(refresh: true),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A JAKIM company: name, head office, contacts, reference, and when its page was read.
class CompanyDetails extends StatelessWidget {
  const CompanyDetails({super.key, required this.company});

  final HalalCompany company;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final c = company;
    final hq = [
      c.address,
      // JAKIM's address usually ends with the state already.
      if (c.state != null && c.address?.endsWith(c.state!) != true) c.state,
    ].nonNulls.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          c.name,
          key: const ValueKey('company-name'),
          style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        InfoRow(label: l.companyHq, value: hq),
        InfoRow(label: l.companyPhone, value: c.phone),
        InfoRow(label: l.companyFax, value: c.fax),
        InfoRow(label: l.companyEmail, value: c.email),
        InfoRow(
          label: l.companyWebsite,
          value: c.website,
          onTap: () => openLink(
            context,
            c.website!.startsWith('http') ? c.website! : 'https://${c.website}',
            failed: l.openFailed,
          ),
        ),
        InfoRow(label: l.companyReference, value: c.reference),
        const SizedBox(height: 6),
        Text(
          c.readAt == null
              ? l.companyNotRead
              : l.companyReadAt(_day(context, c.readAt!.toLocal())),
          key: const ValueKey('company-read-at'),
          style: text.bodySmall?.copyWith(color: nb.inkSoft),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Edit place > Halal

/// Owner, Edit place > Halal: what the posts say (read only: a quoted claim is never typed in), then the brand's
/// outlets on JAKIM across Malaysia (listed on open; the owner's own words search again). Each row: pair it with one
/// of our branches (its certificate), unpair, or add it as a new branch (no pin: pinned next from Edit branch).
class PlaceHalalEditor extends StatefulWidget {
  const PlaceHalalEditor({super.key, required this.restaurant});

  final PlaceRestaurant restaurant;

  @override
  State<PlaceHalalEditor> createState() => _PlaceHalalEditorState();
}

class _PlaceHalalEditorState extends State<PlaceHalalEditor> {
  // Filled with the place's name: what the list on open searched; the owner edits it to search another name.
  late final _query = TextEditingController(text: widget.restaurant.name);
  bool _searching = false;

  /// The row whose pair / unpair / add is running (its actions show Saving…).
  int? _acting;
  JakimOutlets? _list;

  bool get _busy => _searching || _acting != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_search());
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    final q = _query.text.trim();
    // The name as is = the server's own search (it also keeps only rows naming the place); other words = as typed.
    final own =
        q.length >= 2 &&
        q.toLowerCase() != widget.restaurant.name.trim().toLowerCase();
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final r = await places.placeOutlets(
        widget.restaurant.id,
        q: own ? q : null,
      );
      if (mounted) setState(() => _list = r);
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // Pair, unpair, add: the book reloads, and the list's marks follow it (no new JAKIM search).
  Future<void> _act(int i, Future<void> Function(PlacesController) work) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    setState(() => _acting = i);
    try {
      await work(places);
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _acting = null);
    }
  }

  Future<void> _pair(
    int i,
    JakimOutlet o,
    String url,
    List<Branch> branches,
  ) async {
    final l = AppLocalizations.of(context);
    // The branch at the same postcode first.
    final open = branches.where((b) => !b.closed);
    final options = [
      ...open.where((b) => b.id == o.nearBranchId),
      ...open.where((b) => b.id != o.nearBranchId),
    ];
    final b = await showBasePicker<Branch>(
      context,
      title: l.jakimPairTitle(o.row.premise),
      options: options,
      selected: null,
      label: (b) => b.label ?? b.where ?? '-',
      search: options.length > 6,
    );
    if (b == null || !mounted) return;
    await _act(i, (places) => places.setHalalCert(b.id, o.row, url));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    // The book's copy: reloaded after a pair or a new branch.
    final place = context.select<PlacesController, Place?>(
      (c) => c.places
          .where((p) => p.restaurant.id == widget.restaurant.id)
          .firstOrNull,
    );
    final r = place?.restaurant ?? widget.restaurant;
    final branches = place?.branches ?? const <Branch>[];
    // Which branch holds an outlet's certificate: the book's (fresh after a pair), not the search's.
    String? pairedOf(JakimOutlet o) => branches
        .where((b) => b.halalCert?.premise == o.row.premise)
        .firstOrNull
        ?.id;
    String nameOf(String? id) =>
        branches
            .where((b) => b.id == id)
            .map((b) => b.label ?? b.where)
            .firstOrNull ??
        '-';
    final list = _list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerPanel(
          key: const ValueKey('place-halal-posts'),
          icon: Icons.format_quote_outlined,
          title: l.halalPostsTitle,
          subtitle: l.halalEditClaimNote,
          children: [
            Text(switch (r.halalClaim) {
              'says_halal' => l.halalEditSays(r.halalQuote ?? ''),
              'says_not_halal' => l.halalEditSaysNot(r.halalQuote ?? ''),
              _ => l.halalEditNoClaim,
            }, style: text.bodyMedium),
          ],
        ),
        const SizedBox(height: spaceM),
        OwnerPanel(
          key: const ValueKey('place-halal'),
          icon: Icons.storefront_outlined,
          title: l.halalOutletsTitle,
          subtitle: l.halalOutletsHelp,
          children: [
            TextField(
              key: const ValueKey('place-halal-query'),
              controller: _query,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: l.jakimQuery,
                helperText: l.jakimQueryHelp,
                helperMaxLines: 5,
                suffixIcon: _searching
                    ? _spin
                    : IconButton(
                        key: const ValueKey('place-halal-search'),
                        tooltip: l.jakimSearch,
                        onPressed: _busy ? null : _search,
                        icon: const Icon(Icons.search),
                      ),
              ),
            ),
            const SizedBox(height: spaceM),
            if (_searching)
              PanelLoading(text: l.jakimSearching)
            else if (list != null) ...[
              PanelNotice(
                key: const ValueKey('place-halal-status'),
                tone: list.status == 'unavailable'
                    ? PanelTone.error
                    : list.rows.isEmpty
                    ? PanelTone.warning
                    : PanelTone.info,
                text: list.status == 'unavailable'
                    ? l.jakimCheckDown
                    : list.rows.isEmpty
                    ? l.jakimOutletsNone
                    : list.more
                    ? l.jakimOutletsMore(list.rows.length)
                    : l.jakimOutletsFound(list.rows.length),
              ),
              for (final (i, o) in list.rows.indexed) ...[
                const SizedBox(height: spaceS),
                _RowCard(
                  key: ValueKey('jakim-outlet-$i'),
                  row: o.row,
                  note: pairedOf(o) != null
                      ? Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: nb.pandanDeep,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l.jakimPairedWith(nameOf(pairedOf(o))),
                                style: text.bodySmall?.copyWith(
                                  color: nb.pandanDeep,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : o.nearBranchId != null
                      ? Text(
                          l.jakimNearBranch(nameOf(o.nearBranchId)),
                          style: text.bodySmall?.copyWith(color: nb.pandanDeep),
                        )
                      : null,
                  action: _action(l, i, o, list.url, branches, pairedOf(o)),
                  menu: pairedOf(o) == null && list.url != null
                      ? _menu(l, i, o, list.url!, branches)
                      : null,
                ),
              ],
              if (list.url case final url? when list.rows.isNotEmpty) ...[
                const SizedBox(height: spaceS),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        openLink(context, url, failed: l.openFailed),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(l.halalBrandOpen),
                  ),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  /// A row's one main action: paired = Unpair (red); same postcode as a branch = Pair (that branch); else Pair
  /// with a branch (choose). While any of the row's actions runs, this button turns into the spinner.
  Widget _action(
    AppLocalizations l,
    int i,
    JakimOutlet o,
    String? url,
    List<Branch> branches,
    String? paired,
  ) {
    final off = _busy ? null : () {};
    final busy = _acting == i;
    if (paired case final id?) {
      return BusyButton(
        key: ValueKey('jakim-unpair-$i'),
        kind: BusyButtonKind.danger,
        icon: Icons.link_off,
        label: l.jakimUnpair,
        busyLabel: l.ownerSaving,
        busy: busy,
        onPressed: off == null
            ? null
            : () => _act(i, (p) => p.setHalalCert(id, null, '')),
      );
    }
    if (url == null || branches.isEmpty) return const SizedBox.shrink();
    if (o.nearBranchId case final id?) {
      return BusyButton(
        key: ValueKey('jakim-pair-near-$i'),
        icon: Icons.link,
        label: l.jakimPairThis,
        busyLabel: l.ownerSaving,
        busy: busy,
        onPressed: off == null
            ? null
            : () => _act(i, (p) => p.setHalalCert(id, o.row, url)),
      );
    }
    return BusyButton(
      key: ValueKey('jakim-pair-$i'),
      icon: Icons.link,
      label: l.jakimPair,
      busyLabel: l.ownerSaving,
      busy: busy,
      onPressed: off == null ? null : () => _pair(i, o, url, branches),
    );
  }

  /// The less likely actions of an unpaired row, in the app's ⋮ sheet (as on every tile): pair another branch
  /// (when the main button pairs the same-postcode one), or add the outlet as a new branch of this place.
  Widget? _menu(
    AppLocalizations l,
    int i,
    JakimOutlet o,
    String url,
    List<Branch> branches,
  ) {
    if (branches.isEmpty) return null;
    return IconButton(
      key: ValueKey('jakim-more-$i'),
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.more_vert, color: Notebook.of(context).inkSoft),
      onPressed: _busy
          ? null
          : () => showActionSheet(
              context,
              title: o.row.premise,
              actions: [
                if (o.nearBranchId != null)
                  MenuAction(
                    icon: Icons.link,
                    label: l.jakimPairOther,
                    onTap: () => _pair(i, o, url, branches),
                  ),
                MenuAction(
                  icon: Icons.add_business_outlined,
                  label: l.jakimAddBranch,
                  // A new branch is made beside an existing one (same place).
                  onTap: () => _act(i, (p) async {
                    await p.addSiblingBranch(
                      branches.first.id,
                      address: o.row.address,
                      lat: null,
                      lng: null,
                      cert: o.row,
                      certUrl: url,
                    );
                    if (mounted) {
                      _snack(
                        context,
                        AppLocalizations.of(context).jakimBranchAdded,
                      );
                    }
                  }),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Edit place > Company

typedef _Row = ({String branchId, String? label, BranchCompany info});

/// Owner, Edit place > Company: each certified branch of the place with its company. "Get missing" refreshes only the
/// branches with no company page read yet; "Get all again" every one. One by one, each with its own refresh (a certificate paired by hand is checked on JAKIM first), its own
/// progress and its own answer; "Get again" on one branch does that one.
class PlaceCompanyPanel extends StatefulWidget {
  const PlaceCompanyPanel({super.key, required this.placeId});

  final String placeId;

  @override
  State<PlaceCompanyPanel> createState() => _PlaceCompanyPanelState();
}

class _PlaceCompanyPanelState extends State<PlaceCompanyPanel> {
  PlaceCompanies? _list;

  /// Per branch: its newest read, after a refresh (with that refresh's status).
  final _fresh = <String, BranchCompany>{};

  /// Branches being read now; [_done] of [_total] in a "Get all again" (0 = none running).
  final _reading = <String>{};
  int _done = 0, _total = 0;

  /// The run under way is "Get missing" (else "Get all again").
  bool _missingRun = false;

  bool get _all => _total > 0;

  /// Branches whose company page was never read (no company, or only its name from the directory row).
  List<String> get _missing => [
    for (final b in _list ?? const <_Row>[])
      if ((_fresh[b.branchId] ?? b.info).company?.readAt == null) b.branchId,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final l = AppLocalizations.of(context);
    try {
      final r = await context.read<PlacesController>().placeCompanies(
        widget.placeId,
      );
      if (mounted) setState(() => _list = r);
    } catch (e) {
      if (!mounted) return;
      _snack(context, errorText(l, e));
      setState(() => _list = const []);
    }
  }

  Future<void> _readOne(PlacesController places, String branchId) async {
    final l = AppLocalizations.of(context);
    setState(() => _reading.add(branchId));
    try {
      final r = await places.branchCompany(
        branchId,
        refresh: true,
        reload: false,
      );
      if (mounted) setState(() => _fresh[branchId] = r);
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _reading.remove(branchId));
    }
  }

  Future<void> _one(String branchId) async {
    final places = context.read<PlacesController>();
    await _readOne(places, branchId);
    await places.reloadBook();
  }

  Future<void> _everyOne({bool missing = false}) async {
    final places = context.read<PlacesController>();
    final ids = missing
        ? _missing
        : [for (final b in _list ?? const <_Row>[]) b.branchId];
    setState(() {
      _done = 0;
      _total = ids.length;
      _missingRun = missing;
    });
    for (final id in ids) {
      if (!mounted) return;
      await _readOne(places, id);
      if (mounted) setState(() => _done++);
    }
    await places.reloadBook();
    if (!mounted) return;
    _snack(context, AppLocalizations.of(context).companiesDone(ids.length));
    setState(() => _total = 0);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final list = _list;
    final missing = _missing.length;
    final progress = l.companiesReadingN(
      (_done + 1).clamp(1, _total.clamp(1, 1 << 30)),
      _total,
    );
    return OwnerPanel(
      key: const ValueKey('place-companies'),
      icon: Icons.business_outlined,
      title: l.companiesTitle,
      subtitle: l.companiesHelp,
      children: [
        if (list == null)
          PanelLoading(text: l.ownerLoading)
        else if (list.isEmpty)
          PanelNotice(text: l.companiesNone, tone: PanelTone.info)
        else ...[
          PanelActions(
            children: [
              if (!(_all && _missingRun))
                BusyButton(
                  key: const ValueKey('place-companies-refresh'),
                  kind: BusyButtonKind.outlined,
                  icon: Icons.refresh,
                  label: l.companiesRefreshAll,
                  busyLabel: progress,
                  busy: _all,
                  onPressed: _reading.isEmpty ? _everyOne : null,
                ),
              if (missing > 0 && !(_all && !_missingRun))
                BusyButton(
                  key: const ValueKey('place-companies-missing'),
                  icon: Icons.download_outlined,
                  label: l.companiesGetMissing(missing),
                  busyLabel: progress,
                  busy: _all,
                  onPressed: _reading.isEmpty
                      ? () => _everyOne(missing: true)
                      : null,
                ),
            ],
          ),
          for (final b in list) ...[
            const SizedBox(height: spaceM),
            Divider(height: 1, color: nb.line),
            const SizedBox(height: spaceM),
            _branchBlock(l, nb, b),
          ],
        ],
      ],
    );
  }

  Widget _branchBlock(AppLocalizations l, Notebook nb, _Row b) {
    final text = Theme.of(context).textTheme;
    final fresh = _fresh[b.branchId];
    final info = fresh ?? b.info;
    final c = info.company;
    final reading = _reading.contains(b.branchId);
    return Column(
      key: ValueKey('place-company-${b.branchId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 20, color: nb.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.label ?? info.premise ?? '-',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (info.premise case final p? when p != b.label)
                    Text(p, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: spaceS),
            // While it reads, the line under the name says so.
            if (!reading)
              TextButton.icon(
                key: ValueKey('place-company-refresh-${b.branchId}'),
                onPressed: _all || _reading.isNotEmpty
                    ? null
                    : () => _one(b.branchId),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.companyRefreshOne),
              ),
          ],
        ),
        const SizedBox(height: spaceS),
        Padding(
          // Under the branch's name, past its icon.
          padding: const EdgeInsets.only(left: 30),
          child: reading
              ? PanelLoading(text: l.companyReading)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Each branch's own answer, small: a box per branch would repeat down the list.
                    if (fresh?.status case final s?) ...[
                      _RowStatus(
                        text: switch (s) {
                          'ok' => l.companyRowUpdated,
                          'unavailable' => l.jakimDownShort,
                          _ => l.companyNone,
                        },
                        tone: switch (s) {
                          'ok' => PanelTone.success,
                          'unavailable' => PanelTone.error,
                          _ => PanelTone.warning,
                        },
                      ),
                      const SizedBox(height: spaceS),
                    ],
                    if (c != null)
                      CompanyDetails(company: c)
                    else
                      Text(
                        l.companiesNoneYet,
                        style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One branch's answer in a list: an icon and a short coloured line.
class _RowStatus extends StatelessWidget {
  const _RowStatus({required this.text, required this.tone});

  final String text;
  final PanelTone tone;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final (icon, color) = switch (tone) {
      PanelTone.success => (Icons.check_circle, nb.pandanDeep),
      PanelTone.error => (Icons.cloud_off_outlined, nb.margin),
      _ => (Icons.help_outline, nb.inkSoft),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
