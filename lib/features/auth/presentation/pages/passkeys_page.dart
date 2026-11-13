import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/auth_api.dart';
import '../../data/passkey_auth.dart';
import '../../domain/passkey.dart';
import '../auth_text.dart';

/// Account > Passkeys: the account's passkeys (GET /auth/passkeys), "Create a passkey" on a phone that can, and
/// Remove. A removed passkey stops signing in at once; the phone's password manager still lists it until deleted there.
class PasskeysPage extends StatefulWidget {
  const PasskeysPage({super.key, this.api, this.passkeys});

  /// Tests pass fakes; the app uses the shared Dio and the provided PasskeyAuth (null = this phone cannot make one).
  final AuthApi? api;
  final PasskeyAuth? passkeys;

  @override
  State<PasskeysPage> createState() => _PasskeysPageState();
}

class _PasskeysPageState extends State<PasskeysPage> {
  /// The API's limit per account.
  static const _max = 10;

  late final AuthApi _api =
      widget.api ?? AuthApi(context.read<ApiClient>().dio);
  late final PasskeyAuth? _phone =
      widget.passkeys ?? context.read<PasskeyAuth?>();
  List<Passkey>? _list;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await apiCall(_api.passkeys);
      if (mounted) {
        setState(() {
          _list = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add(PasskeyAuth phone) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final response = await phone.create(
        await apiCall(_api.passkeyRegisterOptions),
      );
      if (response == null) return; // closed the sheet
      await apiCall(() => _api.addPasskey(response));
      if (mounted) _say(l.passkeysAdded);
    } catch (e) {
      if (mounted) _say(errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<void> _remove(Passkey p) async {
    final l = AppLocalizations.of(context);
    if (!await showNotebookDialog(
      context,
      message: l.passkeysRemoveConfirm(p.name ?? l.passkeysUnnamed),
      tone: DialogTone.danger,
      confirmLabel: l.passkeysRemove,
    )) {
      return;
    }
    try {
      await apiCall(() => _api.deletePasskey(p.id));
    } catch (e) {
      if (mounted) _say(errorText(l, e));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final dates = MaterialLocalizations.of(context);
    final list = _list;
    final phone = _phone;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.passkeysTitle)),
      body: NotebookPage(
        child: list == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator.adaptive()
                    : TextButton(onPressed: _load, child: Text(l.tryAgain)),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    InfoCard(icon: Icons.fingerprint, text: l.passkeysInfo),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l.passkeysEmpty,
                          style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                        ),
                      ),
                    for (final p in list)
                      NotebookRow(
                        mark: Icon(Icons.key, size: 20, color: nb.inkSoft),
                        trailing: TextButton(
                          onPressed: () => _remove(p),
                          child: Text(
                            l.passkeysRemove,
                            style: TextStyle(color: nb.margin),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name ?? l.passkeysUnnamed),
                            Text(
                              [
                                l.passkeysCreated(
                                  dates.formatMediumDate(p.createdAt),
                                ),
                                p.lastUsedAt == null
                                    ? l.passkeysNeverUsed
                                    : l.sessionsLastUsed(
                                        dates.formatMediumDate(p.lastUsedAt!),
                                      ),
                              ].join(' · '),
                              style: text.bodySmall?.copyWith(
                                color: nb.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (phone == null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l.passkeysNoPhone,
                          style: text.bodySmall?.copyWith(color: nb.inkSoft),
                        ),
                      )
                    else if (list.length < _max)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.icon(
                          key: const ValueKey('passkey-add'),
                          onPressed: _busy ? null : () => _add(phone),
                          icon: const Icon(Icons.add),
                          label: Text(l.passkeysAdd),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
