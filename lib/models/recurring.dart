import 'category.dart';

/// A template an expense or income repeats from. The server materialises
/// real rows out of it on schedule; the rule itself never holds money.
class RecurringRule {
  const RecurringRule({
    required this.uuid,
    required this.kind,
    required this.title,
    required this.amount,
    required this.frequency,
    required this.startsOn,
    required this.nextRunOn,
    required this.active,
    this.category,
    this.endsOn,
    this.lastRunOn,
    this.note,
  });

  final String uuid;

  /// expense | income
  final String kind;

  /// The expense item or the income source.
  final String title;

  /// Money is a string ("12.50") end to end — see the API doc's money note.
  final String amount;

  /// Set for expense rules only; income has no category.
  final Category? category;

  /// daily | weekly | monthly | yearly
  final String frequency;

  final String startsOn;
  final String? endsOn;

  /// The next occurrence still to be created.
  final String nextRunOn;
  final String? lastRunOn;
  final bool active;
  final String? note;

  bool get isExpense => kind == 'expense';

  /// Past its end date and switched off by the server, as opposed to paused
  /// by hand.
  bool get ended {
    if (active || endsOn == null || endsOn!.isEmpty) return false;
    final end = DateTime.tryParse(endsOn!);
    if (end == null) return false;
    final now = DateTime.now();
    return end.isBefore(DateTime(now.year, now.month, now.day));
  }

  factory RecurringRule.fromJson(Map<String, dynamic> json) => RecurringRule(
        uuid: json['uuid'] as String,
        kind: json['kind'] as String? ?? 'expense',
        title: json['title'] as String? ?? '',
        amount: json['amount'] as String? ?? '0.00',
        category: json['category'] is Map<String, dynamic>
            ? Category.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        frequency: json['frequency'] as String? ?? 'monthly',
        startsOn: json['starts_on'] as String? ?? '',
        endsOn: json['ends_on'] as String?,
        nextRunOn: json['next_run_on'] as String? ?? '',
        lastRunOn: json['last_run_on'] as String?,
        active: json['active'] as bool? ?? true,
        note: json['note'] as String?,
      );
}

/// The frequencies the server accepts, in the order the pickers show them.
const recurringFrequencies = ['daily', 'weekly', 'monthly', 'yearly'];

/// 'monthly' → 'Monthly'
String frequencyLabel(String frequency) => switch (frequency) {
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'yearly' => 'Yearly',
      _ => frequency,
    };
