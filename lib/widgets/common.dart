import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/recurring.dart';
import '../models/user.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import 'glass.dart';

/// The small pieces every tab shares — eyebrow labels, progress bars, error
/// states — kept in one place so the tabs read alike.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.onBrand = false, this.color});

  final String text;

  /// Sitting on the accent colour rather than the page, so the label is white
  /// held back to 70% — a full-strength eyebrow competes with the figure it
  /// introduces.
  final bool onBrand;

  /// Overrides both defaults where a card wants the label at a particular
  /// weight — the dashboard's month card, where it reads at full white.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color:
            color ??
            (onBrand
                ? Colors.white.withValues(alpha: 0.7)
                : AppTheme.faint(context, 0.45)),
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
              child: Text(tr('Try again')),
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
///
/// Sized by its parent — an `Expanded` in a row, a grid cell — so it carries
/// no side padding of its own. A pill that has to size to its label, as in a
/// wrapping row of them, passes [padding].
class PillSegment extends StatelessWidget {
  const PillSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 40,
    this.padding = EdgeInsets.zero,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final EdgeInsetsGeometry padding;

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
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? AppTheme.accent(context)
                  : AppTheme.faint(context, 0.10),
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

/// One row of [showOptionSheet].
class SheetOption<T> {
  const SheetOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A short list of choices, as a sheet from the bottom.
///
/// The menu a dropdown opens is an overlay pinned to the field, which on a
/// form page lands wherever the field happens to be and covers whatever is
/// under it. A sheet always arrives from the same edge, within reach of the
/// thumb, and is dismissed the same way as every other sheet in the app.
///
/// Resolves to the chosen value, or null when dismissed.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
  T? current,
}) {
  return showGlassSheet<T>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pageInset,
          14,
          AppTheme.pageInset,
          8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final option in options)
              ListTile(
                leading: option.icon == null
                    ? null
                    : Icon(
                        option.icon,
                        size: 20,
                        color: AppTheme.faint(context, 0.6),
                      ),
                title: Text(option.label),
                trailing: option.value == current
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: AppTheme.accent(context),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A field that opens [showOptionSheet] and shows what was chosen — the
/// dropdown's shape without the dropdown's menu.
class OptionField<T> extends StatelessWidget {
  const OptionField({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final List<SheetOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// An icon at the head of the field, where the dropdown had a prefix.
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final chosen = options.where((o) => o.value == value).toList();
    final label = chosen.isEmpty ? '' : chosen.first.label;

    return InkWell(
      onTap: () async {
        final picked = await showOptionSheet<T>(
          context,
          title: title,
          options: options,
          current: value,
        );

        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(AppTheme.rowRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: leading == null
              ? null
              : Icon(leading, size: 20, color: AppTheme.faint(context, 0.5)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            Icon(
              Icons.expand_more,
              size: 20,
              color: AppTheme.faint(context, 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Repeat" line the expense and income forms share on create: Never plus
/// the four frequencies. Choosing any frequency turns the save into a
/// recurring rule rather than a single row.
class RepeatRow extends StatelessWidget {
  const RepeatRow({super.key, required this.value, required this.onChanged});

  /// A frequency from [recurringFrequencies], or null for "never".
  final String? value;
  final ValueChanged<String?> onChanged;

  static const _never = 'never';

  @override
  Widget build(BuildContext context) {
    return OptionField<String>(
      title: tr('Repeat'),
      leading: Icons.repeat,
      value: value ?? _never,
      options: [
        SheetOption(value: _never, label: tr('Never repeats')),
        for (final f in recurringFrequencies)
          SheetOption(value: f, label: tr(frequencyLabel(f))),
      ],
      onChanged: (v) => onChanged(v == _never ? null : v),
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
          tooltip: tr('Previous month'),
        ),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthLabel(month),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: AppTheme.faint(context, 0.5),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(shiftMonth(month, 1)),
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
          tooltip: tr('Next month'),
        ),
      ],
    );
  }
}

/// A sheet with a year stepper over a grid of the twelve months. Resolves to
/// the chosen `YYYY-MM`, or null when dismissed.
Future<String?> showMonthPicker(
  BuildContext context, {
  required String current,
}) {
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late int _year = int.parse(widget.current.split('-').first);

  String _ym(int month) => '$_year-${month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = currentYm();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pageInset,
          10,
          AppTheme.pageInset,
          16,
        ),
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
                  tooltip: tr('Previous year'),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: tr('Next year'),
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
              onPressed: today == widget.current
                  ? null
                  : () => Navigator.of(context).pop(today),
              child: Text(tr('This month')),
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

/// The frame a form page sits in: a title with a close button over the fields,
/// scrolling out from under the keyboard rather than being squeezed by it.
///
/// Replaces the bottom sheets these forms used to open in. A sheet holding an
/// amount, a currency toggle, a date picker and a category list is a page
/// wearing a sheet's clothes, and on a short screen the keyboard left it
/// nowhere to go.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.formKey,
    this.actions,
    this.footer,
  });

  final String title;

  /// A line under the title saying what the form is for, where the sheet had
  /// one. Null where the title says it already.
  final String? subtitle;

  final List<Widget> children;

  /// Wraps the fields in a [Form] when given, so validators run.
  final GlobalKey<FormState>? formKey;

  /// App-bar actions — Delete, where a row can be removed from its own page.
  final List<Widget>? actions;

  /// What the page is for — Save, and the delete beneath it — pinned to the
  /// bottom rather than scrolling with the fields. On a long form the action
  /// was off-screen exactly when someone had finished and reached for it.
  final List<Widget>? footer;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        AppTheme.pageInset,
        8,
        AppTheme.pageInset,
        // The keyboard is handled by the Scaffold, which shrinks the page and
        // lifts the footer above it; this is only the last field's breathing
        // room over whatever sits below.
        24,
      ),
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.faint(context, 0.5),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...children,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: glassBack(context),
        title: Text(title),
        actions: actions,
      ),
      body: formKey == null ? body : Form(key: formKey, child: body),
      // The Scaffold's own slot, so the keyboard lifts it rather than covering
      // it, and the fields scroll behind the glass instead of under a button
      // that is not there.
      bottomNavigationBar: footer == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.glassFill(context, strong: true),
                border: Border(
                  top: BorderSide(color: AppTheme.glassBorder(context)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pageInset,
                    12,
                    AppTheme.pageInset,
                    12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: footer!,
                  ),
                ),
              ),
            ),
    );
  }
}

/// The back arrow a page wears in its bar: a circle of the same glass the
/// cards and sheets are made of, so it reads as part of the surface rather
/// than an icon dropped on top of it.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.onPressed});

  /// Defaults to popping the route, which is what a back arrow means.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppTheme.glassFill(context),
        shape: CircleBorder(
          side: BorderSide(color: AppTheme.glassBorder(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// [GlassBackButton] for an `AppBar`'s `leading`, or null where there is
/// nothing to go back to — so the bar does not keep a slot for a button it
/// would not show, and a tab root stays flush against its title.
Widget? glassBack(BuildContext context, {VoidCallback? onPressed}) {
  if (onPressed == null && !Navigator.of(context).canPop()) return null;

  return GlassBackButton(onPressed: onPressed);
}

/// Open a form as a page, fading in from the right.
///
/// A short slide rather than a full push: the page is not somewhere further
/// in, it is the same row opened up, and a hundred-percent travel reads as
/// navigation the back arrow then has to undo. The fade is what carries it —
/// the movement only says which way.
Future<T?> openFormPage<T>(BuildContext context, WidgetBuilder builder) {
  // The root navigator, not the tab's: a form is not a place inside the tab
  // it was opened from, and leaving the nav bar under it invites a tap that
  // walks away from half-entered work.
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, _, _) => builder(context),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 190),
      transitionsBuilder: (context, animation, _, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: eased,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.12, 0),
              end: Offset.zero,
            ).animate(eased),
            child: child,
          ),
        );
      },
    ),
  );
}
