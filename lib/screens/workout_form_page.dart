import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/workout.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../widgets/common.dart';

/// Log or edit a session. A full-screen page rather than a sheet: the sets
/// list grows without bound, and a keyboard plus a growing sheet fight.
class WorkoutFormPage extends ConsumerStatefulWidget {
  const WorkoutFormPage({super.key, this.workout});

  final Workout? workout;

  static Future<void> open(BuildContext context, {Workout? workout}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => WorkoutFormPage(workout: workout),
      ),
    );
  }

  @override
  ConsumerState<WorkoutFormPage> createState() => _WorkoutFormPageState();
}

class _WorkoutFormPageState extends ConsumerState<WorkoutFormPage> {
  late DateTime _performedOn = widget.workout != null
      ? DateTime.parse(widget.workout!.performedOn)
      : DateTime.now();
  late final _minutes = TextEditingController(
    text: widget.workout?.durationSeconds != null
        ? '${widget.workout!.durationSeconds! ~/ 60}'
        : '',
  );
  late final _notes = TextEditingController(text: widget.workout?.notes ?? '');

  /// Weights are entered in this unit; the server stores kilograms either way.
  String _unit = 'kg';

  late final List<SetDraft> _sets = widget.workout != null
      ? widget.workout!.sets
          .map((s) => SetDraft(
                exerciseTypeUuid: s.exercise?.uuid,
                reps: s.reps?.toString(),
                weight: s.weightKg?.toString(),
                distanceM: s.distanceM?.toString(),
                durationSeconds: s.durationSeconds?.toString(),
              ))
          .toList()
      : [SetDraft()];

  bool _busy = false;
  String? _error;

  bool get _editing => widget.workout != null;

  @override
  void dispose() {
    _minutes.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _performedOn,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) setState(() => _performedOn = picked);
  }

  Future<void> _save() async {
    final sets = _sets
        .where((s) => s.exerciseTypeUuid != null)
        .map((s) => s.toPayload())
        .toList();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(repositoryProvider).saveWorkout(
            uuid: widget.workout?.uuid,
            performedOn:
                '${_performedOn.year}-${_performedOn.month.toString().padLeft(2, '0')}-${_performedOn.day.toString().padLeft(2, '0')}',
            durationSeconds: _minutes.text.trim().isEmpty
                ? null
                : (int.tryParse(_minutes.text.trim()) ?? 0) * 60,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            sets: sets,
            weightUnit: _unit,
          );

      if (mounted) {
        ref
          ..invalidate(workoutsProvider)
          ..invalidate(workoutSummaryProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not save the workout.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? 'Edit workout' : 'Log a workout',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('${_performedOn.day}/${_performedOn.month}/${_performedOn.year}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    foregroundColor: AppTheme.ink,
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Minutes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(hintText: 'Notes (optional)'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Eyebrow('Sets')),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'kg', label: Text('kg')),
                  ButtonSegment(value: 'lb', label: Text('lb')),
                ],
                selected: {_unit},
                onSelectionChanged: (selection) => setState(() => _unit = selection.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppTheme.green
                        : Colors.white,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _sets.length; i++) ...[
            _SetRow(
              index: i,
              draft: _sets[i],
              exercises: exercises,
              unit: _unit,
              onChanged: () => setState(() {}),
              onRemove: _sets.length > 1
                  ? () => setState(() => _sets.removeAt(i))
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() {
              // A new set usually repeats the movement just done.
              final previous = _sets.isNotEmpty ? _sets.last : null;
              _sets.add(SetDraft(exerciseTypeUuid: previous?.exerciseTypeUuid));
            }),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add set'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              foregroundColor: AppTheme.green,
              side: const BorderSide(color: AppTheme.green),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_editing ? 'Save changes' : 'Save workout'),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.draft,
    required this.exercises,
    required this.unit,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final SetDraft draft;
  final List<ExerciseType> exercises;
  final String unit;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  ExerciseType? get _selected {
    for (final exercise in exercises) {
      if (exercise.uuid == draft.exerciseTypeUuid) return exercise;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cardio = _selected?.isCardio ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.exerciseTypeUuid,
                    isExpanded: true,
                    decoration: const InputDecoration(hintText: 'Movement'),
                    items: [
                      for (final exercise in exercises)
                        DropdownMenuItem(
                          value: exercise.uuid,
                          child: Row(
                            children: [
                              Icon(
                                CategoryStyle.icon(exercise.icon ?? 'dumbbell'),
                                size: 16,
                                color: CategoryStyle.color(exercise.color),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  exercise.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      draft.exerciseTypeUuid = value;
                      onChanged();
                    },
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: Icon(Icons.close,
                        size: 18, color: Colors.black.withValues(alpha: 0.4)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.reps,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Reps'),
                    onChanged: (v) => draft.reps = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: 'Weight ($unit)'),
                    onChanged: (v) => draft.weight = v,
                  ),
                ),
                if (cardio) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: draft.distanceM,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Meters'),
                      onChanged: (v) => draft.distanceM = v,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
