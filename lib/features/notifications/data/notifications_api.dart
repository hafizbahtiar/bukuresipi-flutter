import 'package:dio/dio.dart';

import '../../../core/network/db_time.dart';
import '../domain/inbox.dart';

class NotificationsApi {
  NotificationsApi(this._dio);

  final Dio _dio;

  /// The newest 50, and how many came since the inbox was last opened: GET /notifications.
  Future<({List<InboxItem> items, int unread})> list() async {
    final j = (await _dio.get<Map<String, dynamic>>('/notifications')).data!;
    return (
      items: [
        for (final n
            in (j['notifications'] as List).cast<Map<String, dynamic>>())
          InboxItem(
            id: n['id'] as int,
            title: n['title'] as String,
            body: n['body'] as String,
            data: (n['data'] as Map).cast<String, String>(),
            fromOwner: n['fromOwner'] as bool,
            image: n['image'] as String?,
            createdAt: dbTime(n['createdAt'] as String).toLocal(),
          ),
      ],
      unread: j['unread'] as int,
    );
  }

  /// Out of this user's inbox only: DELETE /notifications/:id.
  Future<void> hide(int id) => _dio.delete<void>('/notifications/$id');

  /// The inbox was opened: everything in it is read.
  Future<void> seen() => _dio.post<void>('/notifications/seen');
}
