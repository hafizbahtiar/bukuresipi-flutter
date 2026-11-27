import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/load_view.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/system_pages.dart';
import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../push/push_controller.dart';
import '../../../push/push_routes.dart';
import '../../data/notifications_api.dart';
import '../../domain/inbox.dart';

/// Home's bell: every push the phone got, and the owner's messages, newest first. Opening it marks all read; a tap
/// opens what the push opens.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.api});

  /// Tests pass a fake; the app builds one from the shared Dio.
  final NotificationsApi? api;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsApi _api =
      widget.api ?? NotificationsApi(context.read<ApiClient>().dio);
  late Future<({List<InboxItem> items, int unread})> _inbox = _load();

  Future<({List<InboxItem> items, int unread})> _load() async {
    final r = await apiCall(_api.list);
    // Read now; a failed mark only leaves the dot on until the next open.
    if (r.unread > 0) apiCall(_api.seen).ignore();
    return r;
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _inbox = next; // a block: an arrow would return the Future, which setState refuses
    });
    await next;
  }

  Future<void> _remove(InboxItem n) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await apiCall(() => _api.hide(n.id));
      messenger.showSnackBar(SnackBar(content: Text(l.inboxRemoved)));
      await _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  void _open(InboxItem n) {
    if (n.data['type'] == 'update') {
      updateApp(context);
      return;
    }
    if (n.data['shareId'] case final id?) {
      return context.read<PushController?>()?.onTap?.call(id);
    }
    if (_path(n) case final path?) context.push(path);
  }

  // The owner's message opens nothing more: it is all here.
  String? _path(InboxItem n) => switch (n.data['type']) {
    'message' || null => null,
    final type => pushPath(type, n.data),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final loc = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.inboxTitle)),
      body: FutureBuilder(
        future: _inbox,
        builder: (context, s) {
          if (s.hasError) {
            return LoadView(
              loading: false,
              error: s.error,
              onReload: () async => _reload().catchError((_) {}),
              child: null,
            );
          }
          final r = s.data;
          if (r == null) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: WidePage(
              child: r.items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(spaceL),
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: nb.inkSoft,
                        ),
                        const SizedBox(height: spaceS),
                        Text(
                          l.inboxEmpty,
                          key: const ValueKey('inbox-empty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: nb.inkSoft),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: spaceS),
                      itemCount: r.items.length,
                      itemBuilder: (context, i) {
                        final n = r.items[i];
                        final tappable =
                            n.data['shareId'] != null ||
                            n.data['type'] == 'update' ||
                            _path(n) != null;
                        return BaseTile(
                          key: ValueKey('inbox-$i'),
                          dense: true,
                          // The newest [unread] came since the last open.
                          leading: Icon(
                            n.fromOwner
                                ? Icons.campaign_outlined
                                : Icons.notifications_outlined,
                            color: i < r.unread ? nb.margin : nb.inkSoft,
                          ),
                          title: n.title,
                          subtitle:
                              '${loc.formatMediumDate(n.createdAt)}, ${formatTime(context, n.createdAt)}',
                          // The whole text: the tile's subtitle stops at 2 lines.
                          footer: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(n.body, style: TextStyle(color: nb.ink)),
                              if (n.image case final url?)
                                Padding(
                                  padding: const EdgeInsets.only(top: spaceS),
                                  child: ClipRRect(
                                    key: ValueKey('inbox-image-$i'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      height: 160,
                                      fit: BoxFit.cover,
                                      // Gone or offline: the text is enough.
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: tappable ? () => _open(n) : null,
                          actions: [
                            MenuAction(
                              icon: Icons.delete_outline,
                              label: l.inboxRemove,
                              danger: true,
                              onTap: () => _remove(n),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}
