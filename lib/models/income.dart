class Income {
  const Income({
    required this.uuid,
    required this.source,
    required this.amount,
    required this.receivedOn,
    this.note,
    this.recurring = false,
  });

  final String uuid;
  final String source;

  /// Money is a string ("12.50") end to end — see the API doc's money note.
  final String amount;

  final String receivedOn;
  final String? note;

  /// Created by a recurring rule rather than typed in by hand.
  final bool recurring;

  factory Income.fromJson(Map<String, dynamic> json) => Income(
        uuid: json['uuid'] as String,
        source: json['source'] as String? ?? '',
        amount: json['amount'] as String? ?? '0.00',
        receivedOn: json['received_on'] as String? ?? '',
        note: json['note'] as String?,
        recurring: json['recurring'] as bool? ?? false,
      );
}

/// One line of GET /incomes/summary's `by_source`, already sorted by total.
///
/// Named for what it is rather than for a source: [IncomeSource] is the
/// catalogue row, and one month's takings under a name are not that name.
class IncomeBySource {
  const IncomeBySource({required this.source, required this.total});

  final String source;
  final String total;

  factory IncomeBySource.fromJson(Map<String, dynamic> json) => IncomeBySource(
        source: json['source'] as String? ?? '',
        total: json['total'] as String? ?? '0.00',
      );
}

/// One name in the account's source catalogue — what the income form and the
/// savings deposit form offer, and what the Sources screen manages.
///
/// A suggestion, not a key: an income carries the name as text, so renaming
/// or removing this row need not touch the income filed under it. See the
/// backend's income_sources migration.
class IncomeSource {
  const IncomeSource({
    required this.uuid,
    required this.name,
    required this.uses,
    required this.total,
  });

  final String uuid;
  final String name;

  /// How much income carries this name. Zero for one nothing has used yet.
  final int uses;

  /// What that income adds up to, "0.00" when there is none.
  final String total;

  factory IncomeSource.fromJson(Map<String, dynamic> json) => IncomeSource(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        uses: (json['uses'] as num?)?.toInt() ?? 0,
        total: json['total'] as String? ?? '0.00',
      );
}

class IncomeSummary {
  const IncomeSummary({
    required this.month,
    required this.total,
    required this.count,
    required this.bySource,
  });

  final String month;
  final String total;
  final int count;
  final List<IncomeBySource> bySource;

  factory IncomeSummary.fromJson(Map<String, dynamic> json) => IncomeSummary(
        month: json['month'] as String? ?? '',
        total: json['total'] as String? ?? '0.00',
        count: (json['count'] as num?)?.toInt() ?? 0,
        bySource: (json['by_source'] as List<dynamic>? ?? [])
            .map((e) => IncomeBySource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
