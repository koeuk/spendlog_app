/// Small formatting helpers — the API speaks `YYYY-MM` months, `YYYY-MM-DD`
/// days, and money as `"12.50"` strings that are displayed verbatim.
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String money(String value) => '\$$value';

/// Money with any leading minus dropped.
///
/// The API reports an overspend as `remaining: "-6.00"`. Every screen says
/// "over" in words, so the sign would read twice: "$-6.00 over budget".
String moneyAbs(String value) => money(value.replaceFirst('-', ''));

/// Money with the sign in front of the symbol: "-12.00" → "−$12.00". For the
/// figures that legitimately go negative, like a month's balance.
String moneySigned(String value) =>
    value.startsWith('-') ? '\u2212${moneyAbs(value)}' : money(value);

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

/// A [DateTime] as the API's `YYYY-MM-DD` day parameter.
String dateParam(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// '2026-08' → ('2026-08-01', '2026-08-31'): the inclusive day range a
/// `filter[from]`/`filter[to]` pair needs to cover exactly one month.
({String from, String to}) monthBounds(String ym) {
  final parts = ym.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);

  // Day zero of the next month is the last day of this one.
  final last = DateTime(year, month + 1, 0);

  return (from: '$ym-01', to: dateParam(last));
}

/// Rewrite what is typed in an amount field when the currency toggle moves.
///
/// The alternative — clearing the field — was what every form did while no
/// endpoint exposed the rate, and it threw away a figure the person had just
/// typed. Converting keeps it, and keeps it *true*: the prefix and the number
/// always mean the same amount of money.
///
/// Riel is returned whole. There is no subunit in circulation, and a field
/// reading `៛615000.00` is noise. Dollars keep their cents.
///
/// Returns null when there is nothing to convert — an empty or unparseable
/// field — so the caller can leave it exactly as the person left it.
String? convertAmount(String text, {
  required String from,
  required String to,
  required double khrPerUsd,
}) {
  if (from == to) return null;

  final value = double.tryParse(text.trim());
  if (value == null || value <= 0 || khrPerUsd <= 0) return null;

  if (to == 'KHR') return (value * khrPerUsd).round().toString();

  final usd = value / khrPerUsd;

  // Two places, and trailing zeros trimmed: "12.50" but "12" rather than
  // "12.00", which reads as a figure someone typed rather than a conversion.
  return usd.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
