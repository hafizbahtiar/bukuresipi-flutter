import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../load_view.dart';

/// Owner: shares the pipeline could not finish or read, to tune readers and thresholds. Read only.
class OwnerSharesPage extends StatefulWidget {
  const OwnerSharesPage({super.key});

  @override
  State<OwnerSharesPage> createState() => _OwnerSharesPageState();
}

class _OwnerSharesPageState extends State<OwnerSharesPage> {
  List<FailedShare>? _shares;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await context.read<OwnerRepository>().failedShares();
      if (mounted) {
        setState(() {
          _shares = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shares = _shares;
    final m = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.ownerFailedShares)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: shares == null
            ? null
            : shares.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l.ownerNoFailed, textAlign: TextAlign.center),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: shares.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = shares[i];
                  final at = s.createdAt.toLocal();
                  // What went wrong first: the error code, else the gaps.
                  final why = s.error ?? s.gaps.join(', ');
                  return ListTile(
                    isThreeLine: s.caption != null,
                    title: Text(
                      why,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        '${m.formatShortDate(at)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(at))}, ${s.platform ?? s.input}, ${s.kind}',
                        ?s.sourceUrl,
                        ?s.caption,
                      ].join('\n'),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: s.sourceUrl == null
                        ? null
                        : () => openLink(
                            context,
                            s.sourceUrl!,
                            failed: l.openFailed,
                          ),
                  );
                },
              ),
      ),
    );
  }
}
