import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/workout.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'workout_form_page.dart';

/// The exercise module: this month's training summary, then the sessions.
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        ref.read(workoutsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _delete(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this workout?'),
        content: Text('${dayLabel(workout.performedOn)} — ${workout.sets.length} sets'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider).deleteWorkout(workout.uuid);
      ref
        ..invalidate(workoutsProvider)
        ..invalidate(workoutSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(workoutMonthProvider);
    final summary = ref.watch(workoutSummaryProvider);
    final workouts = ref.watch(workoutsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Workouts',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          MonthStepper(
            label: monthLabel(month),
            onPrevious: () =>
                ref.read(workoutMonthProvider.notifier).state = shiftMonth(month, -1),
            onNext: () =>
                ref.read(workoutMonthProvider.notifier).state = shiftMonth(month, 1),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => WorkoutFormPage.open(context),
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
      body: RefreshIndicator(
        color: AppTheme.green,
        onRefresh: () async {
          await refreshQuietly(ref.refresh(workoutSummaryProvider.future));
          await refreshQuietly(ref.refresh(workoutsProvider.future));
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, AppTheme.navBarClearance + 72),
          children: [
            summary.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppTheme.green)),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(apiErrorMessage(e)),
                ),
              ),
              data: (data) => _SummaryCard(summary: data),
            ),
            const SizedBox(height: 16),
            workouts.when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppTheme.green)),
              ),
              error: (e, _) => LoadFailed(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(workoutsProvider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.fitness_center_outlined,
                              size: 44, color: Colors.black.withValues(alpha: 0.25)),
                          const SizedBox(height: 12),
                          const Text('No workouts yet — log your first session.'),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final workout in state.items) ...[
                      _WorkoutTile(
                        workout: workout,
                        onTap: () => WorkoutFormPage.open(context, workout: workout),
                        onDelete: () => _delete(workout),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (state.hasMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.green),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final WorkoutSummary summary;

  String get _hours {
    final h = summary.durationSeconds ~/ 3600;
    final m = (summary.durationSeconds % 3600) ~/ 60;

    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {

    return Card(
      color: AppTheme.green,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('This month', onBrand: true)),
                if (summary.streak > 0)
                  Text(
                    '🔥 ${summary.streak} day streak',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(value: '${summary.sessions}', label: 'sessions'),
                _Stat(value: '${summary.volumeKg} kg', label: 'volume'),
                _Stat(value: _hours, label: 'time'),
                _Stat(value: '${summary.sets}', label: 'sets'),
              ],
            ),
            if (summary.breakdown.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final split in summary.breakdown) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        split.label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${split.sets} sets · ${split.volumeKg} kg',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ],
            if (summary.records.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Eyebrow('Personal records', onBrand: true),
              const SizedBox(height: 8),
              for (final record in summary.records.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        '${record.weightKg} kg × ${record.reps}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({
    required this.workout,
    required this.onTap,
    required this.onDelete,
  });

  final Workout workout;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final minutes = (workout.durationSeconds ?? 0) ~/ 60;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center,
                    size: 20, color: AppTheme.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel(workout.performedOn),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${workout.sets.length} sets',
                        if (minutes > 0) '$minutes min',
                        if ((workout.volumeKg ?? 0) > 0) '${workout.volumeKg} kg',
                        if (workout.notes?.isNotEmpty ?? false) workout.notes!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              // The session's muscle groups as colour dots.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in workout.sets
                      .map((s) => s.exercise?.color)
                      .whereType<String>()
                      .toSet()
                      .take(4))
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: CategoryStyle.color(color),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
