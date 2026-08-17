import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/category_style.dart';

/// The small pieces every tab shares — eyebrow labels, progress bars, error
/// states — kept in one place so the tabs read alike.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.onBrand = false});

  final String text;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: onBrand
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.45),
          ),
    );
  }
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.percent,
    required this.status,
    this.onBrand = false,
  });

  /// Already capped at 100 server-side (`bar_percent`).
  final num percent;
  final String status;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 7,
        child: Stack(
          children: [
            Container(
              color: onBrand
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            FractionallySizedBox(
              widthFactor: (percent.clamp(0, 100)) / 100,
              child: Container(
                color: onBrand ? Colors.white : CategoryStyle.statusColor(status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadFailed extends StatelessWidget {
  const LoadFailed({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: Colors.black.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 44),
                backgroundColor: AppTheme.green,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One pill in a segmented row — the Week / Month / Year / All toggle the
/// Reports tab and the dashboard's spending card both wear. Shared so the two
/// cannot drift into looking like two different controls for the same choice.
///
/// [height] is the only thing they disagree on: the dashboard's copy sits
/// inside a card beside other content, so it runs shorter than the one heading
/// the Reports screen.
class PillSegment extends StatelessWidget {
  const PillSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 40,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.green : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppTheme.green : Colors.black.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Month stepper: ‹ August 2026 ›
class MonthStepper extends StatelessWidget {
  const MonthStepper({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
