/// D1 datetimes are UTC without a zone ("2026-11-02 12:00:00").
DateTime dbTime(String s) =>
    DateTime.parse(s.contains('T') ? s : '${s.replaceFirst(' ', 'T')}Z');
