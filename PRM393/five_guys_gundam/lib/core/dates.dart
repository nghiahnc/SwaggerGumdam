/// Dates from the API are UTC, but only values the API has just written carry
/// a "Z". Values read back from SQL Server come without a zone suffix
/// (`2026-10-20T07:00:00`), and `DateTime.parse` would read those as device
/// time: a voucher ending at 14:00 in Vietnam would show 07:00, and saving it
/// again would move it 7 hours earlier. Read both forms as UTC.
DateTime parseUtc(String raw) {
  final hasZone = RegExp(r'(Z|[+-]\d\d:?\d\d)$', caseSensitive: false);
  return DateTime.parse(hasZone.hasMatch(raw) ? raw : '${raw}Z').toUtc();
}

/// `dd/MM/yyyy HH:mm` in device time, e.g. `20/10/2026 14:00`.
String formatLocal(DateTime value) {
  final t = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}
