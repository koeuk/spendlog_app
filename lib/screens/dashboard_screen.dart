import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/dashboard.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final month = ref.watch(dashboardMonthProvider);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hi, ${user?.name.split(' ').first ?? ''} 👋',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          MonthStepper(
            label: monthLabel(month),
            onPrevious: () =>
                ref.read(dashboardMonthProvider.notifier).state = shiftMonth(month, -1),
            onNext: () =>
                ref.read(dashboardMonthProvider.notifier).state = shiftMonth(month, 1),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.green,
          onRefresh: () => refreshQuietly(ref.refresh(dashboardProvider.future)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, AppTheme.navBarClearance),
            children: [
              _MonthCard(data: data),
              const SizedBox(height: 16),
              _TodayCard(total: data.todayTotal),
              const SizedBox(height: 16),
              const _SpendingCard(),
              if (data.breakdown.isNotEmpty) ...[
                const SizedBox(height: 16),
                _BreakdownCard(data: data),
              ],
              if (data.recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RecentCard(data: data),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context) {
    final overall = data.summary.overall;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: AppTheme.green,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('This month', onBrand: true),
            const SizedBox(height: 8),
            Text(
              money(overall.spent),
              style: textTheme.headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (overall.budget != null) ...[
              ProgressTrack(percent: overall.barPercent, status: overall.status, onBrand: true),
              const SizedBox(height: 8),
              Text(
                overall.status == 'over'
                    ? '${moneyAbs(overall.remaining ?? '0.00')} over the ${money(overall.budget!)} budget'
                    : '${money(overall.remaining ?? '0.00')} left of ${money(overall.budget!)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
            ] else
              Text(
                'No budget set for ${monthLabel(data.budgetMonth)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.total});

  final String total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Today'),
            const SizedBox(height: 8),
            Text(
              money(total),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Spending by category'),
            const SizedBox(height: 16),
            for (final slice in data.breakdown) ...[
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: CategoryStyle.color(slice.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(slice.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    money(slice.spent),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${slice.share}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
              if (slice != data.breakdown.last) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Recent expenses'),
            const SizedBox(height: 12),
            for (final expense in data.recent) ...[
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CategoryStyle.color(expense.category?.color)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CategoryStyle.icon(expense.category?.icon),
                      size: 18,
                      color: CategoryStyle.color(expense.category?.color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      expense.item,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(money(expense.price),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (expense != data.recent.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
