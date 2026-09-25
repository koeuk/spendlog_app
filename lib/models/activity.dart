/// One line of GET /activity: who did what to which record, and for updates
/// what changed.
class ActivityEntry {
  const ActivityEntry({
    required this.uuid,
    required this.action,
    required this.subject,
    required this.label,
    required this.changes,
    required this.userName,
    required this.createdAt,
  });

  final String uuid;

  /// created | updated | deleted
  final String action;

  /// expense | income | budget | category | savings_plan | savings_entry |
  /// borrowing | borrowing_repayment
  final String subject;

  /// Frozen when the line was written, so it still reads after a delete.
  final String label;

  final List<ActivityChange> changes;
  final String userName;
  final DateTime createdAt;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['changes'] as Map<String, dynamic>?;

    return ActivityEntry(
      uuid: json['uuid'] as String,
      action: json['action'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      label: json['label'] as String? ?? '',
      changes: [
        for (final entry in (raw ?? const {}).entries)
          ActivityChange(
            field: entry.key,
            // A change value is normally a {from, to} object, but tolerate a
            // scalar (e.g. {"note": "hello"}) rather than crashing the feed.
            from: entry.value is Map<String, dynamic>
                ? (entry.value as Map<String, dynamic>)['from']?.toString()
                : null,
            to: entry.value is Map<String, dynamic>
                ? (entry.value as Map<String, dynamic>)['to']?.toString()
                : entry.value?.toString(),
          ),
      ],
      userName: (json['user'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ActivityChange {
  const ActivityChange({required this.field, this.from, this.to});

  final String field;
  final String? from;
  final String? to;

  /// "category_id" → "category", "spent_on" → "spent on".
  String get fieldLabel =>
      field.replaceFirst(RegExp(r'_id$'), '').replaceAll('_', ' ');
}

/// One end of an activity window: a `YYYY-MM-DD` day, and optionally an
/// `HH:mm` time within it. A bare day covers all of it server-side.
class ActivityMoment {
  const ActivityMoment(this.day, [this.time]);

  final String day;
  final String? time;

  /// The API's form: `2026-09-25` or `2026-09-25T18:00`.
  String get param => time == null ? day : '${day}T$time';

  ActivityMoment withTime(String? next) => ActivityMoment(day, next);

  @override
  bool operator ==(Object other) =>
      other is ActivityMoment && other.day == day && other.time == time;

  @override
  int get hashCode => Object.hash(day, time);
}

/// What the Activity screen is narrowed to. [personUuid] and [everyone] are
/// admin-only; the dates are open to anyone looking at their own log.
class ActivityFilter {
  const ActivityFilter({
    this.everyone = false,
    this.personUuid,
    this.personName,
    this.from,
    this.to,
  });

  /// The account's own log, all of it: where the screen starts.
  static const mine = ActivityFilter();

  final bool everyone;
  final String? personUuid;
  final String? personName;
  final ActivityMoment? from;
  final ActivityMoment? to;

  bool get isFiltered =>
      everyone || personUuid != null || from != null || to != null;

  // Compared by value: the notifier depends on this, and an identical filter
  // must not refetch from page one.
  @override
  bool operator ==(Object other) =>
      other is ActivityFilter &&
      other.everyone == everyone &&
      other.personUuid == personUuid &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(everyone, personUuid, from, to);
}
