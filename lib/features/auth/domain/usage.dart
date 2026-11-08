/// The caller's own limits (GET /usage). [period] 'day' resets at [resetsAt]; 'total' is a size cap (the list).
class Usage {
  const Usage({required this.items, required this.resetsAt});

  factory Usage.fromJson(Map<String, dynamic> j) => Usage(
    items: [
      for (final i in j['items'] as List)
        (
          code: i['code'] as String,
          used: i['used'] as int,
          limit: i['limit'] as int,
          daily: i['period'] == 'day',
        ),
    ],
    resetsAt: DateTime.parse(j['resetsAt'] as String).toLocal(),
  );

  final List<({String code, int used, int limit, bool daily})> items;
  final DateTime resetsAt;
}
