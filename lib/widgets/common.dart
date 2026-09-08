import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import 'glass.dart';

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
            : AppTheme.faint(context, 0.45),
      ),
    );
  }
}

/// The "create" button every list tab floats above its content: a pill the
/// same height as the nav bar's active tab, so the two read as one family.
/// Already lifted clear of the floating nav bar, so use it directly as a
/// Scaffold's `floatingActionButton`.
class AddPill extends StatelessWidget {
  const AddPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.fabNavBarOffset),
      child: Material(
        color: AppTheme.accent(context),
        shape: const StadiumBorder(),
        elevation: 6,
        shadowColor: AppTheme.accent(context).withValues(alpha: 0.35),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 21, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.percent,
    this.status = 'ok',
    this.onBrand = false,
    this.color,
  });

  /// Already capped at 100 server-side (`bar_percent`).
  final num percent;
  final String status;
  final bool onBrand;

  /// An explicit fill — a savings goal's own colour — instead of the one
  /// [status] implies. Ignored when [onBrand], where the fill is always white.
  final Color? color;

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
                  : AppTheme.faint(context, 0.06),
            ),
            FractionallySizedBox(
              widthFactor: (percent.clamp(0, 100)) / 100,
              child: Container(
                color: onBrand
                    ? Colors.white
                    : color ?? CategoryStyle.statusColor(status),
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
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppTheme.faint(context, 0.3),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 44),
                backgroundColor: AppTheme.accent(context),
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
      color: selected ? AppTheme.accent(context) : AppTheme.glassFill(context),
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
              color: selected ? AppTheme.accent(context) : AppTheme.faint(context, 0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// The account's photo, or its initial on green while it has none (or while
/// the photo fails to load — a dead URL should not leave a blank square).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    required this.size,
    this.circle = false,
  });

  final User? user;
  final double size;

  /// A circle for the big profile portrait; rounded square elsewhere.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final initial = (user?.name.isNotEmpty ?? false)
        ? user!.name[0].toUpperCase()
        : '?';
    final url = user?.avatarUrl;

    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.41,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.accent(context),
        borderRadius: BorderRadius.circular(circle ? size : size * 0.32),
      ),
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Steps a `YYYY-MM` month back and forth, and jumps to any month when the
/// label is tapped. Owns the arithmetic so screens only store the value.
class MonthStepper extends StatelessWidget {
  const MonthStepper({super.key, required this.month, required this.onChanged});

  final String month;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final chosen = await showMonthPicker(context, current: month);

    if (chosen != null && chosen != month) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onChanged(shiftMonth(month, -1)),
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
          tooltip: 'Previous month',
        ),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(monthLabel(month), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                Icon(Icons.expand_more, size: 18, color: AppTheme.faint(context, 0.5)),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(shiftMonth(month, 1)),
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

/// A sheet with a year stepper over a grid of the twelve months. Resolves to
/// the chosen `YYYY-MM`, or null when dismissed.
Future<String?> showMonthPicker(BuildContext context, {required String current}) {
  return showGlassSheet<String>(
    context: context,
    builder: (context) => _MonthPickerSheet(current: current),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.current});

  final String current;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year = int.parse(widget.current.split('-').first);

  String _ym(int month) => '$_year-${month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = currentYm();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.pageInset, 10, AppTheme.pageInset, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.faint(context, 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous year',
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next year',
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.9,
              children: [
                for (var m = 1; m <= 12; m++)
                  PillSegment(
                    label: _months[m - 1],
                    selected: _ym(m) == widget.current,
                    onTap: () => Navigator.of(context).pop(_ym(m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // The way back after wandering years away.
            TextButton(
              onPressed: today == widget.current ? null : () => Navigator.of(context).pop(today),
              child: const Text('This month'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ten CategoryColor swatches as a row of tappable circles. Categories and
/// savings goals both pick from the same enum, so they share the picker.
class SwatchPicker extends StatelessWidget {
  const SwatchPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final name in CategoryStyle.colorNames)
          GestureDetector(
            onTap: () => onSelected(name),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: CategoryStyle.color(name),
                shape: BoxShape.circle,
                border: Border.all(
                  color: name == selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: name == selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}
