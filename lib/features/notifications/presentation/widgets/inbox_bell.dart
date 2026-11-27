import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/notifications_api.dart';

/// Home's bell: a dot while the inbox has something new; opens it. Read again when Home is built and on return.
class InboxBell extends StatefulWidget {
  const InboxBell({super.key, this.api});

  /// Tests pass a fake; the app builds one from the shared Dio.
  final NotificationsApi? api;

  @override
  State<InboxBell> createState() => _InboxBellState();
}

class _InboxBellState extends State<InboxBell> {
  late final NotificationsApi? _api =
      widget.api ??
      switch (context.read<ApiClient?>()) {
        final c? => NotificationsApi(c.dio),
        null => null,
      };
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api?.list();
      if (r != null && mounted) setState(() => _unread = r.unread);
    } catch (_) {
      // Offline or signed out: no dot, the page says why.
    }
  }

  @override
  Widget build(BuildContext context) => _api == null
      ? const SizedBox.shrink()
      : IconButton(
          key: const ValueKey('feed-inbox'),
          tooltip: AppLocalizations.of(context).inboxTitle,
          icon: Badge(
            isLabelVisible: _unread > 0,
            child: const Icon(Icons.notifications_none),
          ),
          onPressed: () async {
            await context.push('/notifications');
            if (mounted) setState(() => _unread = 0);
            _load();
          },
        );
}
