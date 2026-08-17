import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/report.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../utils/report_export.dart';
import '../widgets/common.dart';
import '../widgets/spending_chart.dart';

const _granularities = [
  (value: 'week', label: 'Week'),
  (value: 'month', label: 'Month'),
  (value: 'year', label: 'Year'),
  (value: 'all', label: 'All'),
];

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (canExportReports)
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.ios_share, size: 21),
              onPressed: () => _pickExportFormat(context, ref),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(reportProvider),
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.green,
          onRefresh: () => refreshQuietly(ref.refresh(reportProvider.future)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, AppTheme.navBarClearance),
            children: [
              _PeriodBar(data: data),
              const SizedBox(height: 16),
              _TotalCard(stats: data.stats, label: data.periodLabel),
              const SizedBox(height: 12),
              _FiguresRow(stats: data.stats, breakdown: data.breakdown),
              const SizedBox(height: 16),
              _ChartCard(data: data),
              const SizedBox(height: 16),
              _BreakdownCard(breakdown: data.breakdown),
            ],
          ),
        ),
      ),
    );
  }
}

/// Granularity toggle above the period picker. Switching granularity drops the
/// anchor — '2026-08' is not a period a year view can show.
class _PeriodBar extends ConsumerWidget {
  const _PeriodBar({required this.data});

  final Report data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final notifier = ref.read(reportPeriodProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final option in _granularities)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _Segment(
                    label: option.label,
                    selected: data.granularity == option.value,
                    onTap: () => notifier.state = period.withGranularity(option.value),
                  ),
                ),
              ),
          ],
        ),
        // All time is one span; there is nothing for a picker to choose between.
        if (data.granularity != 'all' && data.options.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PeriodPicker(data: data),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.green : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 40,
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

/// The period field, opening a bottom sheet rather than a dropdown.
///
/// A dropdown's overlay is anchored to the field and grows with the list — a
/// year view offers 24 months, which covered the whole report behind it. A
/// sheet is bounded, dismissible by dragging, and matches every other picker
/// in the app.
class _PeriodPicker extends ConsumerWidget {
  const _PeriodPicker({required this.data});

  final Report data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The server bounds the list by the account's own history, so a new user is
    // not offered ten empty years to browse.
    final selected = data.options.firstWhere(
      (option) => option.value == data.anchor,
      orElse: () => data.options.first,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      child: InkWell(
        onTap: () => _choose(context, ref, selected.value),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref, String current) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _PeriodSheet(options: data.options, current: current),
    );

    if (chosen == null) return;

    ref.read(reportPeriodProvider.notifier).state =
        ref.read(reportPeriodProvider).withAnchor(chosen);
  }
}

class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.options, required this.current});

  final List<PeriodOption> options;
  final String current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        // Bounded, so a 24-month list stays a picker rather than becoming a
        // full page you have to dismiss to see what you were reading.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Choose a period',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isCurrent = option.value == current;

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    selected: isCurrent,
                    selectedTileColor: AppTheme.green.withValues(alpha: 0.10),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check, size: 20, color: AppTheme.green)
                        : null,
                    onTap: () => Navigator.of(context).pop(option.value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.stats, required this.label});

  final ReportStats stats;
  final String label;

  @override
  Widget build(BuildContext context) {
    final change = stats.changePercent;
    final up = (change ?? 0) > 0;

    return Card(
      color: AppTheme.green,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Total spent', onBrand: true),
            const SizedBox(height: 8),
            Text(
              money(stats.total),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (change == null)
              Text(
                'Nothing before $label to compare with',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              )
            else
              Row(
                children: [
                  Icon(
                    up ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      // The server truncates the previous period to the same
                      // elapsed stretch while this one is still running, so say
                      // "so far" rather than implying a whole-period comparison.
                      '${up ? '+' : ''}$change% vs ${stats.previousLabel}'
                      '${stats.previousIsPartial ? ' so far' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FiguresRow extends StatelessWidget {
  const _FiguresRow({required this.stats, required this.breakdown});

  final ReportStats stats;
  final List<ReportBreakdownRow> breakdown;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight is what makes `stretch` legal here: inside a ListView the
    // row's height is unbounded, and stretching into that expands both cards
    // without limit, pushing everything below them off the screen.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Figure(
              eyebrow: 'Daily average',
              value: money(stats.dailyAverage),
              caption: 'Over elapsed days only',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Figure(
              eyebrow: 'Transactions',
              value: '${stats.count}',
              caption: breakdown.isEmpty
                  ? 'Nothing logged'
                  : 'Across ${breakdown.length} categor${breakdown.length == 1 ? 'y' : 'ies'}',
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.eyebrow, required this.value, required this.caption});

  final String eyebrow;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Eyebrow(eyebrow),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data});

  final Report data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Spending'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  money(data.seriesTotal),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    data.seriesLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SpendingChart(buckets: data.buckets),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.breakdown});

  final List<ReportBreakdownRow> breakdown;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('By category'),
            const SizedBox(height: 16),
            if (breakdown.isEmpty)
              Text(
                'Nothing logged in this period.',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
              ),
            for (final slice in breakdown) ...[
              _SliceRow(slice: slice),
              if (slice != breakdown.last)
                Divider(height: 24, color: Colors.black.withValues(alpha: 0.05)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SliceRow extends StatelessWidget {
  const _SliceRow({required this.slice});

  final ReportBreakdownRow slice;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(slice.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(CategoryStyle.icon(slice.icon), size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slice.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${slice.count} × ${money(slice.average)} avg',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(slice.total),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${slice.share}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressTrack(percent: slice.share, status: 'ok'),
      ],
    );
  }
}

/// PDF for reading, Excel/CSV for spreadsheets — same three the web offers.
Future<void> _pickExportFormat(BuildContext context, WidgetRef ref) async {
  final period = ref.read(reportPeriodProvider);

  final format = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          for (final (format, label, icon) in [
            ('pdf', 'PDF report', Icons.picture_as_pdf_outlined),
            ('xlsx', 'Excel spreadsheet', Icons.table_chart_outlined),
            ('csv', 'CSV file', Icons.description_outlined),
          ])
            ListTile(
              leading: Icon(icon, color: AppTheme.green),
              title: Text(label),
              onTap: () => Navigator.of(context).pop(format),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (format == null || !context.mounted) return;

  await exportReport(
    context,
    format: format,
    period: period.granularity,
    anchor: period.anchor,
  );
}
