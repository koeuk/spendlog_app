import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models/dashboard.dart';
import '../models/report.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/spending_chart.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthNotifier, User?>((auth) => auth.state.user);
    final month = context.watch<DashboardMonth>().value;
    final dashboard = context.watch<DashboardNotifier>().state;

    return Scaffold(
      // No app bar: the greeting row below is the header, and it needs the
      // avatar and two lines of text that a title slot cannot hold.
      body: dashboard.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => context.read<DashboardNotifier>().invalidate(),
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.accent(context),
          onRefresh: () {
            // The chart loads on its own notifier, so a pull that only
            // refreshed the dashboard call would leave it showing stale money
            // beside freshly updated cards.
            context.read<DashboardTrendReportNotifier>().invalidate();

            // `refresh` never throws — see AsyncNotifier.refresh — so the
            // future handed back here cannot surface as an unhandled error.
            return context.read<DashboardNotifier>().refresh();
          },
          // Slivers rather than a ListView: the greeting is a header that
          // collapses into a frosted bar as the cards pass under it, and only
          // a persistent header can be told how far it has been scrolled.
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _GreetingHeader(
                  user: user,
                  topInset: MediaQuery.paddingOf(context).top,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageInset,
                  4,
                  AppTheme.pageInset,
                  AppTheme.navBarClearance,
                ),
                sliver: SliverList.list(
                  children: [
                    // The month being viewed sits with the card it governs
                    // rather than in the header, where it would squeeze the
                    // greeting.
                    Align(
                      alignment: Alignment.centerRight,
                      child: MonthStepper(
                        month: month,
                        onChanged: (ym) =>
                            context.read<DashboardMonth>().value = ym,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MonthCard(data: data),
                    const SizedBox(height: 16),
                    _TodayCard(total: data.todayTotal),
                    // Hidden entirely against a server that predates income
                    // and savings, rather than showing two cards of zeros.
                    if (data.incomeTotal != null || data.savings != null) ...[
                      const SizedBox(height: 16),
                      _MoneyRow(data: data),
                    ],
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Who is signed in: photo on the left, a time-of-day greeting in small grey
/// over the name in bold. Tapping it goes to Settings, where the photo and
/// name are changed.
///
/// A header that collapses rather than a row that scrolls away, the way an
/// iOS large title does: at rest it is the tall greeting on the bare ground,
/// and as the cards rise under it the greeting line fades, the photo shrinks
/// and a frosted bar comes up behind the name. The person's name stays on
/// screen the whole way down, which is the point — a header that leaves takes
/// the only thing saying whose money this is with it.
class _GreetingHeader extends SliverPersistentHeaderDelegate {
  const _GreetingHeader({required this.user, required this.topInset});

  final User? user;

  /// The status bar, which the header draws its glass up behind.
  final double topInset;

  /// The compact bar: an avatar and the name, at the usual bar height.
  static const _collapsedBody = 56.0;

  /// The greeting at rest, with room for both lines beside a 46pt photo.
  static const _expandedBody = 74.0;

  @override
  double get minExtent => topInset + _collapsedBody;

  @override
  double get maxExtent => topInset + _expandedBody;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    // 0 at rest, 1 once fully collapsed. Everything below reads off this one
    // number, so the pieces cannot fall out of step with each other.
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    final avatar = lerpDouble(46, 34, t)!;
    final greetingHeight = lerpDouble(16, 0, t)!;

    // No explicit height: the delegate is handed a box of exactly the right
    // extent already, and sizing it again from `shrinkOffset` hands the child
    // a smaller box than it was laid out in — which a pinned header, held at
    // `minExtent` while `shrinkOffset` keeps climbing, overflows.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fades in as it collapses: at rest the greeting sits on the bare
        // ground like a large title, with nothing ruled off behind it.
        if (t > 0)
          Opacity(
            opacity: t,
            child: GlassPanel(
              strong: true,
              blur: 26,
              borderRadius: BorderRadius.zero,
              child: const SizedBox.expand(),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            topInset,
            AppTheme.pageInset,
            0,
          ),
          child: InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  UserAvatar(user: user, size: avatar, circle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Height animated to nothing rather than only faded,
                        // so the name rises into the bar's centre instead of
                        // leaving a gap where the greeting was.
                        SizedBox(
                          height: greetingHeight,
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxHeight: 16,
                            child: Opacity(
                              opacity: 1 - t,
                              child: Text(
                                tr(_greeting()),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: AppTheme.faint(context, 0.55),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          user?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: lerpDouble(20, 17, t),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_GreetingHeader old) =>
      old.user != user || old.topInset != topInset;
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context) {
    final overall = data.summary.overall;
    final textTheme = Theme.of(context).textTheme;

    final accent = AppTheme.accent(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        // A shallow gradient rather than a flat fill: the card is the one
        // block of colour on the screen, and a single tone that size reads as
        // printed on. Two stops of the same hue give it a surface.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, 0.12)!,
            accent,
            Color.lerp(accent, Colors.black, 0.10)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        // Tinted, not grey: a neutral shadow under a coloured card looks like
        // dirt under it.
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr('This month'), onBrand: true),
            const SizedBox(height: 10),
            Text(
              money(overall.spent),
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            if (overall.budget != null) ...[
              ProgressTrack(
                percent: overall.barPercent,
                status: overall.status,
                onBrand: true,
              ),
              const SizedBox(height: 8),
              Text(
                overall.status == 'over'
                    ? '${moneyAbs(overall.remaining ?? '0.00')} over the ${money(overall.budget!)} budget'
                    : '${money(overall.remaining ?? '0.00')} left of ${money(overall.budget!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ] else
              Text(
                'No budget set for ${monthLabel(data.budgetMonth)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            if (data.balance != null) ...[
              const SizedBox(height: 4),
              Text(
                'Balance ${moneySigned(data.balance!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Income and savings side by side: the two figures the month card's balance
/// is made of, each a door into its own screen.
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.data});

  final Dashboard data;

  @override
  Widget build(BuildContext context) {
    final savings = data.savings;

    // IntrinsicHeight so the two cards stand equally tall even when one has
    // a second line and the other does not; a bare stretch in a ListView's
    // unbounded height would ask each card to be infinite.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MoneyCard(
              label: tr('Income'),
              value: money(data.incomeTotal ?? '0.00'),
              detail: monthLabel(data.budgetMonth),
              onTap: () => context.go('/income'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MoneyCard(
              label: tr('Savings'),
              value: money(savings?.totalSaved ?? '0.00'),
              detail: savings == null
                  ? ''
                  : savings.hasPlan
                  ? '${money(savings.savedThisMonth)} of ${money(savings.planned)} ${tr('this month')}'
                  : tr('No plan'),
              onTap: () => context.go('/savings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Eyebrow(label)),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.faint(context, 0.25),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.faint(context, 0.45),
                  ),
                ),
              ],
            ],
          ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr('Today')),
            const SizedBox(height: 8),
            Text(
              money(total),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spend over time, the same chart the Reports tab heads with — here it answers
/// "is this month unusual?" without leaving the home screen.
///
/// Loads on its own provider rather than riding [dashboardProvider]: the series
/// is a second round trip, and hanging it off the main call would hold every
/// card on screen hostage to it. A failure here costs the chart, not the
/// dashboard.
class _SpendingCard extends StatelessWidget {
  const _SpendingCard();

  @override
  Widget build(BuildContext context) {
    final granularity = context.watch<DashboardTrend>().value;
    final report = context.watch<DashboardTrendReportNotifier>().state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr('Spending')),
            const SizedBox(height: 6),
            // Total and label come from the loaded series, so they are read off
            // the async value rather than held here.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  money(report.valueOrNull?.seriesTotal ?? '0.00'),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    report.valueOrNull?.seriesLabel ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.faint(context, 0.45),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final option in trendGranularities)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PillSegment(
                        label: option.label,
                        selected: granularity == option.value,
                        height: 32,
                        onTap: () =>
                            context.read<DashboardTrend>().value = option.value,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Fixed height across all three states so switching period does not
            // make the cards below it jump.
            SizedBox(
              height: 170,
              child: report.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accent(context),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    apiErrorMessage(e, fallback: 'Could not load spending.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.faint(context, 0.45),
                    ),
                  ),
                ),
                data: (data) => SpendingChart(buckets: data.buckets),
              ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr('Spending by category')),
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
                    child: Text(
                      slice.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
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
                        color: AppTheme.faint(context, 0.45),
                      ),
                    ),
                  ),
                ],
              ),
              if (slice != data.breakdown.last)
                Divider(height: 16, color: AppTheme.faint(context, 0.06)),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr('Recent expenses')),
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
                  Text(
                    money(expense.price),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // A hairline between rows, taking the gap's place: 24 tall so
              // the rows keep the same 12 either side of it.
              if (expense != data.recent.last)
                Divider(
                  height: 16,
                  // thickness: 1,
                  color: AppTheme.faint(context, 0.06),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
