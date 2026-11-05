import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/auth_api.dart';
import '../auth_text.dart';

/// "Signed-in devices": every live session of this account (GET /auth/sessions), this phone first.
/// Signing one out ends it at once (its next call is 401) and drops its push device.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, this.api});

  /// Tests pass a fake; the app uses the shared Dio.
  final AuthApi? api;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late final AuthApi _api =
      widget.api ?? AuthApi(context.read<ApiClient>().dio);
  List<Map<String, dynamic>>? _sessions;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await apiCall(_api.sessions);
      if (mounted) {
        setState(() {
          _sessions = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function() call) async {
    final l = AppLocalizations.of(context);
    try {
      await apiCall(call);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(l, e))));
      }
    }
    await _load();
  }

  Future<void> _end(Map<String, dynamic> s) async {
    final l = AppLocalizations.of(context);
    if (await showNotebookDialog(
      context,
      message: l.sessionsEndConfirm(_name(l, s)),
      tone: DialogTone.danger,
      confirmLabel: l.sessionsEnd,
    )) {
      await _run(() => _api.endSession(s['id'] as String));
    }
  }

  Future<void> _endOthers() async {
    final l = AppLocalizations.of(context);
    if (await showNotebookDialog(
      context,
      message: l.sessionsEndOthersConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.sessionsEndOthers,
    )) {
      await _run(_api.endOtherSessions);
    }
  }

  String _name(AppLocalizations l, Map<String, dynamic> s) =>
      (s['deviceName'] as String?) ?? l.sessionsUnknownDevice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final dates = MaterialLocalizations.of(context);
    String when(String iso) =>
        dates.formatMediumDate(DateTime.parse(iso).toLocal());
    final sessions = _sessions;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.sessionsTitle)),
      body: NotebookPage(
        child: sessions == null
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
                    for (final s in sessions)
                      NotebookRow(
                        mark: Icon(
                          s['platform'] == 'web'
                              ? Icons.language
                              : Icons.smartphone,
                          size: 20,
                          color: nb.inkSoft,
                        ),
                        trailing: s['current'] == true
                            ? null
                            : TextButton(
                                onPressed: () => _end(s),
                                child: Text(l.sessionsEnd),
                              ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_name(l, s)),
                            Text(
                              s['current'] == true
                                  ? l.sessionsThisDevice
                                  : l.sessionsLastUsed(
                                      when(s['lastUsedAt'] as String),
                                    ),
                              style: text.bodySmall?.copyWith(
                                color: s['current'] == true
                                    ? nb.pandanDeep
                                    : nb.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (sessions.length > 1)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: _endOthers,
                          child: Text(l.sessionsEndOthers),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
