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

  /// expense | income | budget | category | savings_plan | savings_entry
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
            from: (entry.value as Map<String, dynamic>?)?['from']?.toString(),
            to: (entry.value as Map<String, dynamic>?)?['to']?.toString(),
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
