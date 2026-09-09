/// One movement of money set aside. `amount` is always the absolute figure;
/// `type` says which way it went — the sign lives server-side only.
class SavingsEntry {
  const SavingsEntry({
    required this.uuid,
    required this.type,
    required this.amount,
    required this.savedOn,
    this.note,
  });

  final String uuid;

  /// deposit | withdraw
  final String type;

  final String amount;
  final String savedOn;
  final String? note;

  bool get isDeposit => type == 'deposit';

  factory SavingsEntry.fromJson(Map<String, dynamic> json) => SavingsEntry(
        uuid: json['uuid'] as String,
        type: json['type'] as String? ?? 'deposit',
        amount: json['amount'] as String? ?? '0.00',
        savedOn: json['saved_on'] as String? ?? '',
        note: json['note'] as String?,
      );
}

/// How much the month means to set aside — a budget's twin, on the other side
/// of the ledger. One row per (user, month), upserted by POST /savings/plan.
class SavingsPlan {
  const SavingsPlan({
    required this.uuid,
    required this.month,
    required this.amount,
  });

  final String uuid;

  /// `YYYY-MM`.
  final String month;

  final String amount;

  factory SavingsPlan.fromJson(Map<String, dynamic> json) => SavingsPlan(
        uuid: json['uuid'] as String,
        month: json['month'] as String? ?? '',
        amount: json['amount'] as String? ?? '0.00',
      );
}

/// The month against its plan, plus the all-time balance the headline shows.
class SavingsSummary {
  const SavingsSummary({
    required this.month,
    required this.planned,
    required this.savedThisMonth,
    required this.remaining,
    required this.percent,
    required this.percentRaw,
    required this.status,
    required this.totalSaved,
    required this.entriesCount,
  });

  final String month;

  /// The month's plan, or "0.00" when none is set.
  final String planned;

  /// Deposits minus withdrawals dated within the month; may be negative.
  final String savedThisMonth;

  /// planned − saved, floored at "0.00".
  final String remaining;

  /// 0..100, already capped, so it can drive a bar directly.
  final num percent;

  /// The uncapped figure, which may exceed 100.
  final num percentRaw;

  /// ok | close (>=80) | met (>=100)
  final String status;

  /// Every entry ever, all time — the running balance set aside.
  final String totalSaved;

  final int entriesCount;

  /// True once the month has a plan to measure against.
  bool get hasPlan => (double.tryParse(planned) ?? 0) > 0;

  factory SavingsSummary.fromJson(Map<String, dynamic> json) => SavingsSummary(
        month: json['month'] as String? ?? '',
        planned: json['planned'] as String? ?? '0.00',
        savedThisMonth: json['saved_this_month'] as String? ?? '0.00',
        remaining: json['remaining'] as String? ?? '0.00',
        percent: json['percent'] as num? ?? 0,
        percentRaw: json['percent_raw'] as num? ?? json['percent'] as num? ?? 0,
        status: json['status'] as String? ?? 'ok',
        totalSaved: json['total_saved'] as String? ?? '0.00',
        entriesCount: (json['entries_count'] as num?)?.toInt() ?? 0,
      );
}
