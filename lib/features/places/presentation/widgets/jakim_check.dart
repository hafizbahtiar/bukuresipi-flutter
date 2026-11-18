import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/widgets/base.dart' show showBasePicker;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../places_controller.dart';

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Owner, Edit branch > Halal: this outlet's JAKIM certificate as stored now (the book's copy, so a save shows at
/// once) and "Check JAKIM" (found = saved; not found = pair it from Edit place's list). A branch AI draft's rows
/// ([draft]) show here with Save.
class BranchHalalEditor extends StatefulWidget {
  const BranchHalalEditor({super.key, required this.branch, this.draft});

  final Branch branch;
  final ({String url, List<JakimRow> rows, int? pick})? draft;

  @override
  State<BranchHalalEditor> createState() => _BranchHalalEditorState();
}

class _BranchHalalEditorState extends State<BranchHalalEditor> {
  bool _busy = false;

  /// What the certificate says (premise address, brand, company): read when one is linked, again after a change.
  BranchCompany? _company;
  bool _companyBusy = false;

  Future<void> _loadCompany({bool refresh = false}) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    setState(() => _companyBusy = true);
    try {
      final r = await places.branchCompany(widget.branch.id, refresh: refresh);
      if (!mounted) return;
      setState(() => _company = r);
      if (refresh) {
        _snack(context, switch (r.status) {
          'ok' => l.companyUpdated,
          'unavailable' => l.jakimCheckDown,
          _ => l.companyNone,
        });
      }
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _companyBusy = false);
    }
  }

  /// The last check (or the AI draft's rows): null = not asked yet.
  JakimCheck? _result;

  @override
  void initState() {
    super.initState();
    _fromDraft();
    if (widget.branch.halalCert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadCompany());
      });
    }
  }

  @override
  void didUpdateWidget(BranchHalalEditor old) {
    super.didUpdateWidget(old);
    if (widget.draft != old.draft) _fromDraft();
  }

  void _fromDraft() {
    if (widget.draft case final d?) {
      _result = (status: 'draft', url: d.url, rows: d.rows, pick: d.pick);
    }
  }

  Future<void> _run(Future<void> Function(PlacesController) work) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    setState(() => _busy = true);
    try {
      await work(places);
      if (mounted) unawaited(_loadCompany());
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() => _run((places) async {
    final r = await places.checkHalalBranch(widget.branch.id);
    if (mounted) setState(() => _result = r);
  });

  Future<void> _save(JakimRow row, String url) => _run((places) async {
    await places.setHalalCert(widget.branch.id, row, url);
    if (mounted) _snack(context, AppLocalizations.of(context).jakimCertSaved);
  });

  Future<void> _remove() =>
      _run((places) => places.setHalalCert(widget.branch.id, null, ''));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final soft = text.bodySmall?.copyWith(color: nb.inkSoft);
    final cert = context.select<PlacesController, HalalCert?>(
      (c) =>
          c.places
              .expand((p) => p.branches)
              .where((b) => b.id == widget.branch.id)
              .firstOrNull
              ?.halalCert ??
          widget.branch.halalCert,
    );
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final name = widget.branch.label ?? widget.branch.where ?? '-';
    final result = _result;
    final box = _HalalBox(
      key: const ValueKey('branch-halal'),
      busy: _busy,
      children: [
        if (cert == null) ...[
          Text(l.halalEditNoCert, style: text.bodyMedium),
          const SizedBox(height: spaceS),
        ],
        FilledButton.tonalIcon(
          key: const ValueKey('branch-halal-check'),
          onPressed: _busy ? null : _check,
          icon: const Icon(Icons.search),
          label: Text(l.jakimCheck),
        ),
        if (result != null) ...[
          const SizedBox(height: spaceS),
          Text(
            switch (result.status) {
              'found' => l.jakimCheckFound(name),
              'unavailable' => l.jakimCheckDown,
              // The check's own rows are the brand's: Edit place lists them all, to pair.
              'none' => l.jakimBranchNone(name),
              _ when result.rows.isEmpty => l.jakimCheckNone(name),
              _ => l.jakimChooseTitle(name),
            },
            key: const ValueKey('branch-halal-status'),
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (result.status == 'draft')
            for (final (i, r) in result.rows.indexed)
              ListTile(
                key: ValueKey('jakim-row-$i'),
                contentPadding: EdgeInsets.zero,
                title: Text(r.premise),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.jakimDraftRow(r.address, day.format(r.expiresOn)),
                      style: soft,
                    ),
                    if (i == result.pick) AiBadge(label: l.jakimAiPick),
                  ],
                ),
                trailing: cert?.premise == r.premise
                    ? Text(l.jakimSaved, style: soft)
                    : TextButton(
                        key: ValueKey('jakim-save-$i'),
                        onPressed: _busy || result.url == null
                            ? null
                            : () => _save(r, result.url!),
                        child: Text(l.jakimSaveRow),
                      ),
              ),
          if (result.status == 'draft' && result.rows.isNotEmpty)
            Text(l.jakimDraftNote, style: soft),
        ],
      ],
    );
    final info = _company;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cert != null)
          _CertCard(cert: cert, info: info, busy: _busy, onRemove: _remove),
        box,
        if (cert != null)
          _CompanyCard(
            info: info,
            busy: _companyBusy,
            onRefresh: () => _loadCompany(refresh: true),
          ),
      ],
    );
  }
}

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
  bool _busy = false;
  JakimOutlets? _list;
  PlaceCompanies? _companies;
  bool _companiesBusy = false;

  Future<void> _loadCompanies({bool refresh = false}) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    setState(() => _companiesBusy = true);
    try {
      final r = await places.placeCompanies(
        widget.restaurant.id,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() => _companies = r);
      if (refresh) {
        _snack(context, switch (r.status) {
          'ok' when r.left > 0 => l.companiesLeft(r.left),
          'ok' => l.companyUpdated,
          'unavailable' => l.jakimCheckDown,
          _ => l.companyNone,
        });
      }
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _companiesBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _search();
      unawaited(_loadCompanies());
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(PlacesController) work) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    setState(() => _busy = true);
    try {
      await work(places);
    } catch (e) {
      if (mounted) _snack(context, errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The list again (after a pair, an unpair or a new branch: its marks change).
  Future<void> _load(PlacesController places) async {
    final q = _query.text.trim();
    // The name as is = the server's own search (it also keeps only rows naming the place); other words = as typed.
    final own =
        q.length >= 2 &&
        q.toLowerCase() != widget.restaurant.name.trim().toLowerCase();
    final r = await places.placeOutlets(
      widget.restaurant.id,
      q: own ? q : null,
    );
    if (mounted) setState(() => _list = r);
  }

  Future<void> _search() => _run(_load);

  // Pair, unpair, add: the book reloads, and the list's marks follow it (no new JAKIM search).
  Future<void> _pairWith(JakimOutlet o, String url, String branchId) =>
      _run((places) async {
        await places.setHalalCert(branchId, o.row, url);
        if (mounted) unawaited(_loadCompanies());
      });

  Future<void> _pair(JakimOutlet o, String url, List<Branch> branches) async {
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
    await _pairWith(o, url, b.id);
  }

  Future<void> _unpair(String branchId) => _run((places) async {
    await places.setHalalCert(branchId, null, '');
    if (mounted) unawaited(_loadCompanies());
  });

  Future<void> _add(JakimOutlet o, String url, Branch any) =>
      _run((places) async {
        await places.addSiblingBranch(
          any.id,
          address: o.row.address,
          lat: null,
          lng: null,
          cert: o.row,
          certUrl: url,
        );
        if (mounted) {
          _snack(context, AppLocalizations.of(context).jakimBranchAdded);
          unawaited(_loadCompanies());
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final soft = text.bodySmall?.copyWith(color: nb.inkSoft);
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
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
    final box = _HalalBox(
      key: const ValueKey('place-halal'),
      busy: _busy,
      children: [
        Text(switch (r.halalClaim) {
          'says_halal' => l.halalEditSays(r.halalQuote ?? ''),
          'says_not_halal' => l.halalEditSaysNot(r.halalQuote ?? ''),
          _ => l.halalEditNoClaim,
        }, style: text.bodyMedium),
        Text(l.halalEditClaimNote, style: soft),
        const SizedBox(height: spaceM),
        TextField(
          key: const ValueKey('place-halal-query'),
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _busy ? null : _search(),
          decoration: InputDecoration(
            labelText: l.jakimQuery,
            helperText: l.jakimQueryHelp,
            helperMaxLines: 2,
            suffixIcon: IconButton(
              key: const ValueKey('place-halal-search'),
              tooltip: l.jakimSearch,
              onPressed: _busy ? null : _search,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        if (list != null) ...[
          const SizedBox(height: spaceM),
          Text(
            list.status == 'unavailable'
                ? l.jakimCheckDown
                : list.rows.isEmpty
                ? l.jakimOutletsNone
                : list.more
                ? l.jakimOutletsMore(list.rows.length)
                : l.jakimOutletsFound(list.rows.length),
            key: const ValueKey('place-halal-status'),
            style: text.titleSmall,
          ),
          for (final (i, o) in list.rows.indexed)
            Padding(
              key: ValueKey('jakim-outlet-$i'),
              padding: const EdgeInsets.only(top: spaceS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: spaceS),
                  Text(
                    o.row.premise,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l.jakimDraftRow(o.row.address, day.format(o.row.expiresOn)),
                    style: soft,
                  ),
                  if (pairedOf(o) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: spaceXs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: nb.pandanDeep,
                          ),
                          const SizedBox(width: spaceXs),
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
                      ),
                    )
                  else if (o.nearBranchId != null)
                    Text(
                      l.jakimNearBranch(nameOf(o.nearBranchId)),
                      style: text.bodySmall?.copyWith(color: nb.pandanDeep),
                    ),
                  const SizedBox(height: spaceXs),
                  Wrap(
                    spacing: spaceS,
                    runSpacing: spaceXs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (pairedOf(o) case final id?)
                        TextButton(
                          key: ValueKey('jakim-unpair-$i'),
                          onPressed: _busy ? null : () => _unpair(id),
                          child: Text(l.jakimUnpair),
                        )
                      else ...[
                        // Probably that branch (same postcode): one tap.
                        if ((o.nearBranchId, list.url) case (
                          final id?,
                          final url?,
                        ))
                          FilledButton.tonalIcon(
                            key: ValueKey('jakim-pair-near-$i'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _pairWith(o, url, id),
                            icon: const Icon(Icons.link, size: 18),
                            label: Text(l.jakimPairThis),
                          ),
                        if (branches.isNotEmpty && list.url != null)
                          TextButton.icon(
                            key: ValueKey('jakim-pair-$i'),
                            onPressed: _busy
                                ? null
                                : () => _pair(o, list.url!, branches),
                            icon: const Icon(Icons.link, size: 18),
                            label: Text(
                              o.nearBranchId == null
                                  ? l.jakimPair
                                  : l.jakimPairOther,
                            ),
                          ),
                        // A new branch is made beside an existing one (same place).
                        if (branches.isNotEmpty && list.url != null)
                          TextButton.icon(
                            key: ValueKey('jakim-add-$i'),
                            onPressed: _busy
                                ? null
                                : () => _add(o, list.url!, branches.first),
                            icon: const Icon(
                              Icons.add_business_outlined,
                              size: 18,
                            ),
                            label: Text(l.jakimAddBranch),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          if (list.url case final url? when list.rows.isNotEmpty)
            TextButton.icon(
              onPressed: () => openLink(context, url, failed: l.openFailed),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l.halalBrandOpen),
            ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlaceCompaniesCard(
          list: _companies,
          busy: _companiesBusy,
          onRefresh: () => _loadCompanies(refresh: true),
        ),
        box,
      ],
    );
  }
}

/// The edit pages' Halal block: its title, a progress bar while JAKIM is asked, then [children].
class _HalalBox extends StatelessWidget {
  const _HalalBox({super.key, required this.busy, required this.children});

  final bool busy;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      margin: const EdgeInsets.only(top: spaceM),
      padding: const EdgeInsets.all(spaceM - 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [if (busy) const LinearProgressIndicator(), ...children],
      ),
    );
  }
}

/// The linked certificate as JAKIM lists it: valid or expired at a glance, then its rows, how it was linked, and
/// the two actions (JAKIM's page, remove).
class _CertCard extends StatelessWidget {
  const _CertCard({
    required this.cert,
    required this.info,
    required this.busy,
    required this.onRemove,
  });

  final HalalCert cert;
  final BranchCompany? info;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final expired = cert.expiredAt(DateTime.now());
    final tone = expired ? nb.margin : nb.pandan;
    // The same premise only: a read from before a re-pair is not shown as this certificate's.
    final same = info?.premise == cert.premise ? info : null;
    return _HalalBox(
      key: const ValueKey('branch-cert'),
      busy: false,
      children: [
        Row(
          children: [
            Icon(Icons.verified_outlined, size: 20, color: nb.pandanDeep),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.halalCertTitle,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              key: const ValueKey('branch-cert-status'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: tone.withValues(alpha: 0.5)),
              ),
              child: Text(
                expired ? l.certStatusExpired : l.certStatusValid,
                style: text.labelMedium?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: spaceS),
        _InfoRow(
          id: 'cert-premise',
          label: l.certPremise,
          value: cert.premise,
          strong: true,
        ),
        _InfoRow(
          id: 'cert-address',
          label: l.companyPremiseAddress,
          value: same?.premiseAddress,
        ),
        _InfoRow(id: 'cert-brand', label: l.companyBrand, value: same?.brand),
        _InfoRow(
          id: 'cert-valid',
          label: l.certValidUntil,
          value: day.format(cert.expiresOn),
        ),
        _InfoRow(
          id: 'cert-checked',
          label: l.certChecked,
          value: day.format(cert.checkedAt.toLocal()),
        ),
        if (same != null)
          _InfoRow(
            id: 'cert-source',
            label: l.certLinked,
            value: same.source == 'owner'
                ? l.certSourceOwner
                : l.certSourceAuto,
          ),
        const SizedBox(height: spaceS),
        Wrap(
          spacing: spaceS,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  openLink(context, cert.url, failed: l.openFailed),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l.halalCertOpen),
            ),
            TextButton(
              key: const ValueKey('branch-halal-remove'),
              onPressed: busy ? null : onRemove,
              child: Text(l.halalCertRemove),
            ),
          ],
        ),
      ],
    );
  }
}

/// Label on the left, value on the right; no value = no row.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.id,
    required this.label,
    required this.value,
    this.strong = false,
    this.onTap,
  });

  final String id, label;
  final String? value;
  final bool strong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final style = strong
        ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
        : text.bodyMedium;
    return Padding(
      key: ValueKey(id),
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
          ),
          Expanded(
            child: onTap == null
                ? SelectableText(v, style: style)
                : InkWell(
                    onTap: onTap,
                    child: Text(
                      v,
                      style: style?.copyWith(
                        color: nb.pandanDeep,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Owner only: the company behind the certificate (JAKIM's company page), and "Get company info again" (read now; a
/// hand-paired certificate is checked first).
class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.info,
    required this.busy,
    required this.onRefresh,
  });

  final BranchCompany? info;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final soft = text.bodySmall?.copyWith(color: nb.inkSoft);
    final c = info?.company;
    return _HalalBox(
      key: const ValueKey('branch-company'),
      busy: busy,
      children: [
        Row(
          children: [
            Icon(Icons.business_outlined, size: 20, color: nb.pandanDeep),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.companyTitle,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Text(l.companyOwnerOnly, style: soft),
        const SizedBox(height: spaceS),
        if (c != null)
          _CompanyDetails(company: c)
        else if (info != null)
          Text(l.companyNone, style: text.bodyMedium),
        const SizedBox(height: spaceS),
        OutlinedButton.icon(
          key: const ValueKey('branch-company-refresh'),
          onPressed: busy ? null : onRefresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l.companyRefresh),
        ),
      ],
    );
  }
}

/// A JAKIM company: name, head office, contacts, reference, and when its page was read.
class _CompanyDetails extends StatelessWidget {
  const _CompanyDetails({required this.company});

  final HalalCompany company;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final c = company;
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
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
          style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        _InfoRow(id: 'company-hq', label: l.companyHq, value: hq),
        _InfoRow(id: 'company-phone', label: l.companyPhone, value: c.phone),
        _InfoRow(id: 'company-fax', label: l.companyFax, value: c.fax),
        _InfoRow(id: 'company-email', label: l.companyEmail, value: c.email),
        _InfoRow(
          id: 'company-website',
          label: l.companyWebsite,
          value: c.website,
          onTap: () => openLink(
            context,
            c.website!.startsWith('http') ? c.website! : 'https://${c.website}',
            failed: l.openFailed,
          ),
        ),
        _InfoRow(
          id: 'company-reference',
          label: l.companyReference,
          value: c.reference,
        ),
        const SizedBox(height: 6),
        Text(
          c.readAt == null
              ? l.companyNotRead
              : l.companyReadAt(day.format(c.readAt!.toLocal())),
          key: const ValueKey('company-read-at'),
          style: text.bodySmall?.copyWith(color: nb.inkSoft),
        ),
      ],
    );
  }
}

/// Owner, Edit place > Halal: the companies behind the place's certified outlets, each with its outlets, the
/// outlets with no company yet, and one "Get company info again" for them all.
class _PlaceCompaniesCard extends StatelessWidget {
  const _PlaceCompaniesCard({
    required this.list,
    required this.busy,
    required this.onRefresh,
  });

  final PlaceCompanies? list;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final soft = text.bodySmall?.copyWith(color: nb.inkSoft);
    final branches = list?.branches ?? const [];
    String name(({String branchId, String? label, BranchCompany info}) b) =>
        b.label ?? b.info.premise ?? '-';
    // One entry per company, in the order its first outlet comes.
    final byCompany = <String, (HalalCompany, List<String>)>{};
    for (final b in branches) {
      final c = b.info.company;
      if (c != null) (byCompany[c.code] ??= (c, [])).$2.add(name(b));
    }
    final unlinked = [
      for (final b in branches)
        if (b.info.company == null) name(b),
    ];
    return _HalalBox(
      key: const ValueKey('place-companies'),
      busy: busy,
      children: [
        Row(
          children: [
            Icon(Icons.business_outlined, size: 20, color: nb.pandanDeep),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.companiesTitle,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Text(l.companiesHelp, style: soft),
        const SizedBox(height: spaceS),
        if (list != null && branches.isEmpty)
          Text(l.companiesNone, style: text.bodyMedium),
        for (final (i, (c, outlets)) in byCompany.values.indexed) ...[
          if (i > 0) Divider(height: spaceL, color: nb.line),
          _CompanyDetails(company: c),
          const SizedBox(height: 4),
          Text(
            l.companiesOutlets(outlets.join(', ')),
            key: ValueKey('place-company-outlets-${c.code}'),
            style: text.bodyMedium,
          ),
        ],
        if (unlinked.isNotEmpty) ...[
          const SizedBox(height: spaceS),
          Text(
            l.companiesUnlinked(unlinked.join(', ')),
            key: const ValueKey('place-companies-unlinked'),
            style: soft,
          ),
        ],
        if (byCompany.isNotEmpty) ...[
          const SizedBox(height: spaceS),
          OutlinedButton.icon(
            key: const ValueKey('place-companies-refresh'),
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l.companyRefresh),
          ),
        ],
      ],
    );
  }
}
