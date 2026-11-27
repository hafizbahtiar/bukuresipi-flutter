/// One row of the in-app inbox: a push the phone got, or the owner's message. [data] is the push's data, so a tap
/// opens the same page the push does.
class InboxItem {
  const InboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.fromOwner,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final Map<String, String> data;
  final bool fromOwner;
  final DateTime createdAt;
}
