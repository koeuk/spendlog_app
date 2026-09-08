/// One movement on a goal. `amount` is always the absolute figure; `type`
/// says which way it went — the sign lives server-side only.
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

class SavingsGoal {
  const SavingsGoal({
    required this.uuid,
    required this.name,
    required this.targetAmount,
    required this.saved,
    required this.remaining,
    required this.percent,
    required this.reached,
    required this.color,
    this.deadline,
    this.entries,
  });

  final String uuid;
  final String name;
  final String targetAmount;
  final String saved;

  /// Never below "0.00" — the server floors it.
  final String remaining;

  /// 0..100, already capped, so it can drive a bar directly.
  final num percent;

  final bool reached;

  /// A CategoryColor enum value; see CategoryStyle.color.
  final String color;

  final String? deadline;

  /// Only present on GET /savings/{uuid}; null means "not loaded", not "none".
  final List<SavingsEntry>? entries;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        targetAmount: json['target_amount'] as String? ?? '0.00',
        saved: json['saved'] as String? ?? '0.00',
        remaining: json['remaining'] as String? ?? '0.00',
        percent: json['percent'] as num? ?? 0,
        reached: json['reached'] as bool? ?? false,
        color: json['color'] as String? ?? 'slate',
        deadline: json['deadline'] as String?,
        entries: json['entries'] is List
            ? (json['entries'] as List<dynamic>)
                .map((e) => SavingsEntry.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );
}

class SavingsSummary {
  const SavingsSummary({
    required this.month,
    required this.totalSaved,
    required this.totalTarget,
    required this.percent,
    required this.goalsCount,
    required this.savedThisMonth,
  });

  final String month;
  final String totalSaved;
  final String totalTarget;
  final num percent;
  final int goalsCount;

  /// Deposits minus withdrawals dated within the month; may be negative.
  final String savedThisMonth;

  factory SavingsSummary.fromJson(Map<String, dynamic> json) => SavingsSummary(
        month: json['month'] as String? ?? '',
        totalSaved: json['total_saved'] as String? ?? '0.00',
        totalTarget: json['total_target'] as String? ?? '0.00',
        percent: json['percent'] as num? ?? 0,
        goalsCount: (json['goals_count'] as num?)?.toInt() ?? 0,
        savedThisMonth: json['saved_this_month'] as String? ?? '0.00',
      );
}
