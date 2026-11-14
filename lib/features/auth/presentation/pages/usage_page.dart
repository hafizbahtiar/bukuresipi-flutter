import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/auth_api.dart';
import '../../domain/usage.dart';
import '../auth_controller.dart';
import '../auth_text.dart';

/// Account > Usage: the caller's own limits (links shared, receipt photos, reports today; the shopping list size).
/// The owner also gets the service meters (AI, maps, email).
class UsagePage extends StatefulWidget {
  const UsagePage({super.key, this.api});

  /// Tests pass a fake; the app builds one from the shared Dio.
  final AuthApi? api;

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  late final AuthApi _api =
      widget.api ?? AuthApi(context.read<ApiClient>().dio);
  late Future<Usage> _usage = apiCall(_api.usage);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final owner = context.watch<AuthController>().user?.isOwner ?? false;
    String label(String code) => switch (code) {
      'shares' => l.usageShares,
      'receipts' => l.usageReceipts,
      'meals' => l.usageMeals,
      'reports' => l.usageReports,
      'shopping' => l.usageShopping,
      _ => code,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.usageTitle)),
      body: NotebookPage(
        child: FutureBuilder(
          future: _usage,
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Text(errorText(l, s.error!)));
            }
            final u = s.data;
            if (u == null) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            final resets = MaterialLocalizations.of(context)
                .formatTimeOfDay(TimeOfDay.fromDateTime(u.resetsAt));
            return RefreshIndicator(
              onRefresh: () async {
                final next = apiCall(_api.usage);
                setState(() {
                  _usage = next;
                });
                await next;
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      notebookGutter + 10,
                      8,
                      20,
                      8,
                    ),
                    child: Text(
                      l.usageResets(resets),
                      style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                    ),
                  ),
                  for (final i in u.items)
                    NotebookRow(
                      key: ValueKey('usage-${i.code}'),
                      trailing: Text(
                        '${i.used} / ${i.limit}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: i.used >= i.limit ? nb.kunyit : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label(i.code), style: text.titleMedium),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: i.limit == 0
                                ? 0
                                : (i.used / i.limit).clamp(0, 1),
                            color: i.used >= i.limit ? nb.kunyit : nb.pandan,
                            backgroundColor: nb.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    ),
                  if (owner)
                    NotebookRow(
                      key: const ValueKey('usage-meters'),
                      onTap: () => context.push('/owner/usage'),
                      trailing: const Icon(Icons.chevron_right),
                      child: Text(l.usageMeters, style: text.titleMedium),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
