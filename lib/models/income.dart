class Income {
  const Income({
    required this.uuid,
    required this.source,
    required this.amount,
    required this.receivedOn,
    this.note,
  });

  final String uuid;
  final String source;

  /// Money is a string ("12.50") end to end — see the API doc's money note.
  final String amount;

  final String receivedOn;
  final String? note;

  factory Income.fromJson(Map<String, dynamic> json) => Income(
        uuid: json['uuid'] as String,
        source: json['source'] as String? ?? '',
        amount: json['amount'] as String? ?? '0.00',
        receivedOn: json['received_on'] as String? ?? '',
        note: json['note'] as String?,
      );
}

/// One line of GET /incomes/summary's `by_source`, already sorted by total.
class IncomeSource {
  const IncomeSource({required this.source, required this.total});

  final String source;
  final String total;

  factory IncomeSource.fromJson(Map<String, dynamic> json) => IncomeSource(
        source: json['source'] as String? ?? '',
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
  final List<IncomeSource> bySource;

  factory IncomeSummary.fromJson(Map<String, dynamic> json) => IncomeSummary(
        month: json['month'] as String? ?? '',
        total: json['total'] as String? ?? '0.00',
        count: (json['count'] as num?)?.toInt() ?? 0,
        bySource: (json['by_source'] as List<dynamic>? ?? [])
            .map((e) => IncomeSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
