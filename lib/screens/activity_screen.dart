import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/activity.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../widgets/common.dart';

/// Who did what, newest first. Your own by default; admins can widen it to
/// everyone, at which point each line also names the person.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Fetch the next page a screenful before the end, so scrolling never
      // visibly hits the bottom.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        ref.read(activityProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider.select((s) => s.user?.isAdmin ?? false));
    final everyone = ref.watch(activityEveryoneProvider);
    final activity = ref.watch(activityProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Activity log'))),
      body: Column(
        children: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pageInset, 4, AppTheme.pageInset - 6, 12),
              child: Row(
                children: [
                  for (final (label, value) in const [('Mine', false), ('Everyone', true)])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PillSegment(
                          label: label,
                          selected: everyone == value,
                          onTap: () => ref.read(activityEveryoneProvider.notifier).state = value,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: activity.when(
              loading: () => Center(child: CircularProgressIndicator(color: AppTheme.accent(context))),
              error: (e, _) => LoadFailed(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(activityProvider),
              ),
              data: (data) => RefreshIndicator(
                color: AppTheme.accent(context),
                onRefresh: () => refreshQuietly(ref.refresh(activityProvider.future)),
                child: data.items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(top: 80),
                        children: [
                          Icon(Icons.history, size: 44, color: AppTheme.faint(context, 0.25)),
                          const SizedBox(height: 12),
                          Text(
                            tr('Nothing logged yet.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.faint(context, 0.5)),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.pageInset, 0, AppTheme.pageInset, AppTheme.navBarClearance),
                        itemCount: data.items.length + (data.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == data.items.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent(context)),
                                ),
                              ),
                            );
                          }

                          return _ActivityTile(entry: data.items[index], showUser: everyone);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry, required this.showUser});

  final ActivityEntry entry;
  final bool showUser;

  static const _amber = Color(0xFFB45309);
  static const _red = Color(0xFFDC2626);

  Color _tint(BuildContext context) => switch (entry.action) {
        'deleted' => _red,
        'updated' => _amber,
        _ => AppTheme.accent(context),
      };

  IconData get _icon => switch (entry.subject) {
        'expense' => Icons.receipt_long_outlined,
        'income' => Icons.payments_outlined,
        'budget' => Icons.savings_outlined,
        'category' => Icons.category_outlined,
        'savings_plan' => Icons.flag_outlined,
        'savings_entry' => Icons.swap_vert_rounded,
        _ => Icons.circle_outlined,
      };

  /// "Created expense", "Deleted savings entry".
  String get _headline {
    final verb = entry.action.isEmpty
        ? ''
        : '${entry.action[0].toUpperCase()}${entry.action.substring(1)}';

    return '$verb ${entry.subject.replaceAll('_', ' ')}';
  }

  static String _when(DateTime at) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    if (day == today) return '${tr('Today')} · $time';
    if (day == today.subtract(const Duration(days: 1))) return '${tr('Yesterday')} · $time';

    return '${months[at.month - 1]} ${at.day} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.faint(context, 0.5);
    final meta = [
      _headline,
      if (showUser && entry.userName.isNotEmpty) 'by ${entry.userName}',
      _when(entry.createdAt),
    ].join(' · ');

    return Card(
      shape: AppTheme.rowShape(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _tint(context).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, size: 20, color: _tint(context)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(meta, style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
              ],
            ),
            // What an update changed, one line per field: "price: 2.50 → 3.00".
            if (entry.changes.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final change in entry.changes)
                Padding(
                  padding: const EdgeInsets.only(left: 56, bottom: 3),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 12.5, color: muted),
                      children: [
                        TextSpan(text: '${change.fieldLabel}: '),
                        TextSpan(
                          text: change.from ?? '—',
                          style: const TextStyle(decoration: TextDecoration.lineThrough),
                        ),
                        const TextSpan(text: '  →  '),
                        TextSpan(
                          text: change.to ?? '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
