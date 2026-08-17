/// Small formatting helpers — the API speaks `YYYY-MM` months, `YYYY-MM-DD`
/// days, and money as `"12.50"` strings that are displayed verbatim.
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String money(String value) => '\$$value';

String currentYm() {
  final now = DateTime.now();

  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

/// '2026-08' → 'August 2026'
String monthLabel(String ym) {
  final parts = ym.split('-');
  if (parts.length != 2) return ym;

  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return ym;

  return '${_months[month - 1]} ${parts[0]}';
}

/// '2026-08' ± n months, staying in the API's month format.
String shiftMonth(String ym, int delta) {
  final parts = ym.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]) + delta);

  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

/// '2026-08-17' → 'Aug 17'
String dayLabel(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;

  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return ymd;

  return '${_months[month - 1].substring(0, 3)} ${int.parse(parts[2])}';
}
