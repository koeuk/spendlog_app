/// The exercise module's shapes — GET /workouts, /workouts/summary, /exercises.
class ExerciseType {
  const ExerciseType({
    required this.uuid,
    required this.name,
    required this.isCardio,
    this.muscleGroup,
    this.color,
    this.icon,
    this.isMine = false,
  });

  final String uuid;
  final String name;
  final bool isCardio;
  final String? muscleGroup;
  final String? color;
  final String? icon;
  final bool isMine;

  factory ExerciseType.fromJson(Map<String, dynamic> json) => ExerciseType(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        isCardio: json['is_cardio'] as bool? ?? false,
        muscleGroup: json['muscle_group'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        isMine: json['is_mine'] as bool? ?? false,
      );
}

class WorkoutSet {
  const WorkoutSet({
    required this.setNo,
    this.exercise,
    this.reps,
    this.weightKg,
    this.distanceM,
    this.durationSeconds,
    this.rpe,
  });

  final int setNo;
  final ExerciseType? exercise;
  final int? reps;
  final double? weightKg;
  final int? distanceM;
  final int? durationSeconds;
  final int? rpe;

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        setNo: json['set_no'] as int? ?? 0,
        exercise: json['exercise'] is Map<String, dynamic>
            ? ExerciseType.fromJson(json['exercise'] as Map<String, dynamic>)
            : null,
        reps: json['reps'] as int?,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        distanceM: json['distance_m'] as int?,
        durationSeconds: json['duration_seconds'] as int?,
        rpe: json['rpe'] as int?,
      );
}

class Workout {
  const Workout({
    required this.uuid,
    required this.performedOn,
    required this.sets,
    this.durationSeconds,
    this.notes,
    this.volumeKg,
  });

  final String uuid;
  final String performedOn;
  final int? durationSeconds;
  final String? notes;
  final num? volumeKg;
  final List<WorkoutSet> sets;

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        uuid: json['uuid'] as String,
        performedOn: json['performed_on'] as String? ?? '',
        durationSeconds: json['duration_seconds'] as int?,
        notes: json['notes'] as String?,
        volumeKg: json['volume_kg'] as num?,
        sets: (json['sets'] as List<dynamic>? ?? [])
            .map((e) => WorkoutSet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MuscleSplit {
  const MuscleSplit({
    required this.group,
    required this.label,
    required this.color,
    required this.volumeKg,
    required this.sets,
  });

  final String group;
  final String label;
  final String color;
  final num volumeKg;
  final int sets;

  factory MuscleSplit.fromJson(Map<String, dynamic> json) => MuscleSplit(
        group: json['group'] as String? ?? '',
        label: json['label'] as String? ?? '',
        color: json['color'] as String? ?? 'slate',
        volumeKg: json['volume_kg'] as num? ?? 0,
        sets: json['sets'] as int? ?? 0,
      );
}

class PersonalRecord {
  const PersonalRecord({
    required this.name,
    required this.color,
    required this.weightKg,
    required this.reps,
    required this.performedOn,
    this.icon,
  });

  final String name;
  final String color;
  final String? icon;
  final num weightKg;
  final int reps;
  final String performedOn;

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'slate',
        icon: json['icon'] as String?,
        weightKg: json['weight_kg'] as num? ?? 0,
        reps: json['reps'] as int? ?? 0,
        performedOn: json['performed_on'] as String? ?? '',
      );
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.month,
    required this.sessions,
    required this.volumeKg,
    required this.durationSeconds,
    required this.sets,
    required this.streak,
    required this.breakdown,
    required this.records,
  });

  final String month;
  final int sessions;
  final num volumeKg;
  final int durationSeconds;
  final int sets;
  final int streak;
  final List<MuscleSplit> breakdown;
  final List<PersonalRecord> records;

  factory WorkoutSummary.fromJson(Map<String, dynamic> json) => WorkoutSummary(
        month: json['month'] as String? ?? '',
        sessions: json['sessions'] as int? ?? 0,
        volumeKg: json['volume_kg'] as num? ?? 0,
        durationSeconds: json['duration_seconds'] as int? ?? 0,
        sets: json['sets'] as int? ?? 0,
        streak: json['streak'] as int? ?? 0,
        breakdown: (json['breakdown'] as List<dynamic>? ?? [])
            .map((e) => MuscleSplit.fromJson(e as Map<String, dynamic>))
            .toList(),
        records: (json['records'] as List<dynamic>? ?? [])
            .map((e) => PersonalRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One editable set row in the workout form — the client-side, pre-submit
/// counterpart of [WorkoutSet].
class SetDraft {
  SetDraft({this.exerciseTypeUuid, this.reps, this.weight, this.distanceM, this.durationSeconds});

  String? exerciseTypeUuid;
  String? reps;
  String? weight;
  String? distanceM;
  String? durationSeconds;

  Map<String, dynamic> toPayload() => {
        'exercise_type_uuid': exerciseTypeUuid,
        if (reps?.isNotEmpty ?? false) 'reps': int.tryParse(reps!),
        if (weight?.isNotEmpty ?? false) 'weight': double.tryParse(weight!),
        if (distanceM?.isNotEmpty ?? false) 'distance_m': int.tryParse(distanceM!),
        if (durationSeconds?.isNotEmpty ?? false)
          'duration_seconds': int.tryParse(durationSeconds!),
      };
}
