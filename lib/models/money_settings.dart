/// The two figures a client needs to *enter* money, from GET /settings/money.
///
/// Readable by every signed-in account, not just admins: without the rate an
/// amount field switched to riel can only clear itself, because relabelling a
/// dollar figure as ៛ would store five cents where two hundred dollars was
/// meant.
class MoneySettings {
  const MoneySettings({required this.khrPerUsd, required this.defaultCurrency});

  final double khrPerUsd;

  /// 'USD' or 'KHR' — which currency an amount field starts on.
  final String defaultCurrency;

  /// The rate the app assumes when the server has not answered yet. Only ever
  /// used to keep a field usable, never to store a converted amount: the
  /// server converts what it is sent, at its own rate.
  static const fallbackRate = 4100.0;

  static const fallback = MoneySettings(
    khrPerUsd: fallbackRate,
    defaultCurrency: 'USD',
  );

  factory MoneySettings.fromJson(Map<String, dynamic> json) => MoneySettings(
        khrPerUsd: (json['khr_per_usd'] as num?)?.toDouble() ?? fallbackRate,
        defaultCurrency: json['default_currency'] as String? ?? 'USD',
      );
}
