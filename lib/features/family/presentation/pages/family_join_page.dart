import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/family.dart';
import '../ask.dart';
import '../family_controller.dart';

/// An invite link (bukuresipi.com/family/join?t=, opened as an App Link): what the family is, then Join or Not now.
class FamilyJoinPage extends StatefulWidget {
  const FamilyJoinPage({super.key, required this.token});

  final String? token;

  @override
  State<FamilyJoinPage> createState() => _FamilyJoinPageState();
}

class _FamilyJoinPageState extends State<FamilyJoinPage> {
  late final Future<InvitePreview> _preview = widget.token == null
      ? Future.error(const ApiException('invite_expired'))
      : context.read<FamilyController>().preview(widget.token!);
  bool _joining = false;

  Future<void> _join(InvitePreview p) async {
    final l = AppLocalizations.of(context);
    final family = context.read<FamilyController>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _joining = true);
    try {
      if (await withName(context, () => family.join(widget.token!))) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.familyJoined(p.familyName))),
        );
        router.go('/');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: NotebookPage(
        child: FutureBuilder(
          future: _preview,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (s.hasError) {
              return ListView(
                children: [
                  NotebookRow(
                    minHeight: 96,
                    child: Text(errorText(l, s.error!)),
                  ),
                ],
              );
            }
            final p = s.data!;
            final inThis = p.membership == 'this';
            final blocked = p.isFull || p.membership != null;
            return ListView(
              children: [
                NotebookRow(
                  child: Text(
                    l.familyJoinTitle(p.familyName),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                NotebookRow(
                  child: Text(
                    [
                      if (p.ownerName != null) l.familyJoinOwner(p.ownerName!),
                      l.familyCount(p.memberCount, p.maxMembers),
                    ].join(' · '),
                    style: TextStyle(color: nb.inkSoft),
                  ),
                ),
                NotebookRow(
                  minHeight: 96,
                  child: Text(
                    inThis
                        ? l.familyJoinAlreadyHere
                        : p.membership == 'other'
                        ? l.errAlreadyInFamily
                        : p.isFull
                        ? l.familyJoinFull(p.maxMembers)
                        : l.familyJoinBody,
                    style: blocked && !inThis
                        ? TextStyle(color: nb.margin)
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    notebookGutter + 10,
                    16,
                    20,
                    0,
                  ),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      if (p.membership != null)
                        FilledButton(
                          key: const ValueKey('join-open-family'),
                          onPressed: () => context.go('/family'),
                          child: Text(l.familyOpen),
                        )
                      else
                        FilledButton(
                          key: const ValueKey('join-join'),
                          onPressed: _joining || blocked
                              ? null
                              : () => _join(p),
                          child: Text(l.familyJoin),
                        ),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: Text(l.familyNotNow),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
