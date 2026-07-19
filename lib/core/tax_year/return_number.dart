/// Human filing desk return codes: `{LAST4}-{MM}-{DD}-{SEQ}`
/// Example: `GOVA-07-19-01`, then `02`, `03`, …
class ReturnNumber {
  ReturnNumber._();

  static const timezoneName = 'America/Los_Angeles';

  /// First four A–Z letters of [lastName], uppercased; short names padded with X.
  static String prefixFromLastName(String? lastName) {
    final letters = (lastName ?? '').replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (letters.isEmpty) return 'UNKN';
    final slice = letters.length <= 4 ? letters : letters.substring(0, 4);
    return slice.padRight(4, 'X');
  }

  static String format({
    required String prefix,
    required DateTime date,
    required int sequence,
  }) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final seq = sequence < 1 ? 1 : sequence;
    return '${prefix.toUpperCase()}-$mm-$dd-${seq.toString().padLeft(2, '0')}';
  }

  /// Next sequence for [prefix] on [date] given already-used [existingCodes].
  static String next({
    required String lastName,
    required DateTime date,
    required Iterable<String> existingCodes,
  }) {
    final prefix = prefixFromLastName(lastName);
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final stem = '$prefix-$mm-$dd-';
    var max = 0;
    for (final code in existingCodes) {
      final c = code.trim();
      if (!c.startsWith(stem)) continue;
      final tail = c.substring(stem.length);
      final n = int.tryParse(tail);
      if (n != null && n > max) max = n;
    }
    return format(prefix: prefix, date: date, sequence: max + 1);
  }

  static String? fromWorkspaceJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final direct = (json['return_number'] ?? json['returnNumber'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final meta = json['meta'];
    if (meta is Map) {
      final nested = (meta['return_number'] ?? meta['returnNumber'] ?? '').toString().trim();
      if (nested.isNotEmpty) return nested;
    }
    final data = json['data'];
    if (data is Map) {
      final nested = (data['returnNumber'] ?? data['return_number'] ?? '').toString().trim();
      if (nested.isNotEmpty) return nested;
    }
    return null;
  }
}
