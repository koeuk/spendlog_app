import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/activity.dart';
import '../models/admin.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Who did what, newest first. Your own by default; admins can widen it to
/// everyone, at which point each line also names the person.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Fetch the next page a screenful before the end, so scrolling never
      // visibly hits the bottom.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        context.read<ActivityNotifier>().loadMore();
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
    final isAdmin = context.select<AuthNotifier, bool>(
      (auth) => auth.state.user?.isAdmin ?? false,
    );
    final filter = context.watch<ActivityFilterState>().value;
    final activity = context.watch<ActivityNotifier>().state;

    return Scaffold(
      appBar: AppBar(
        leading: glassBack(context),
        title: Text(tr('Activity log')),
        actions: [
          IconButton(
            tooltip: tr('Filters'),
            icon: Icon(
              Icons.tune,
              color: filter.isFiltered ? AppTheme.accent(context) : null,
            ),
            onPressed: () => _openFilters(context, filter, isAdmin),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (filter.isFiltered)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageInset,
                4,
                AppTheme.pageInset,
                12,
              ),
              child: _FilterSummary(
                filter: filter,
                onClear: () => context.read<ActivityFilterState>().value =
                    ActivityFilter.mine,
              ),
            ),
          Expanded(
            child: activity.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accent(context),
                ),
              ),
              error: (e, _) => LoadFailed(
                message: apiErrorMessage(e),
                onRetry: () => context.read<ActivityNotifier>().invalidate(),
              ),
              data: (data) => RefreshIndicator(
                color: AppTheme.accent(context),
                // `refresh` never throws — see AsyncNotifier.refresh.
                onRefresh: () => context.read<ActivityNotifier>().refresh(),
                child: data.items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(top: 80),
                        children: [
                          Icon(
                            Icons.history,
                            size: 44,
                            color: AppTheme.faint(context, 0.25),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            filter.isFiltered
                                ? tr('Nothing matches these filters.')
                                : tr('Nothing logged yet.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.faint(context, 0.5),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.pageInset,
                          0,
                          AppTheme.pageInset,
                          AppTheme.navBarClearance,
                        ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accent(context),
                                  ),
                                ),
                              ),
                            );
                          }

                          return ActivityTile(
                            entry: data.items[index],
                            showUser: filter.everyone,
                          );
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

Future<void> _openFilters(
  BuildContext context,
  ActivityFilter current,
  bool isAdmin,
) async {
  final state = context.read<ActivityFilterState>();
  final next = await showModalBottomSheet<ActivityFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(initial: current, isAdmin: isAdmin),
  );
  if (next != null) state.value = next;
}

/// The active filters in one line, with a way to drop them all.
class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.filter, required this.onClear});

  final ActivityFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final from = filter.from;
    final to = filter.to;
    final parts = [
      if (filter.everyone) tr('Everyone'),
      if (filter.personName != null) filter.personName!,
      if (from != null && to != null)
        '${_momentLabel(from)} – ${_momentLabel(to)}'
      else if (from != null)
        tr('From :date').replaceAll(':date', _momentLabel(from))
      else if (to != null)
        tr('Until :date').replaceAll(':date', _momentLabel(to)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          children: [
            Icon(Icons.tune, size: 18, color: AppTheme.accent(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                parts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              tooltip: tr('Clear filters'),
              icon: Icon(
                Icons.close,
                size: 18,
                color: AppTheme.faint(context, 0.55),
              ),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

String _momentLabel(ActivityMoment moment) => moment.time == null
    ? dayLabel(moment.day)
    : '${dayLabel(moment.day)} ${moment.time}';

String _hm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Whose log (admins only) and when: each end a day, and optionally a time.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.isAdmin});

  final ActivityFilter initial;
  final bool isAdmin;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ActivityFilter _draft = widget.initial;

  bool get _backwards {
    final from = _draft.from;
    final to = _draft.to;
    // `YYYY-MM-DD[THH:mm]` compares correctly as text; a bare end day means
    // its last minute, so give it one before comparing.
    if (from == null || to == null) return false;
    final end = to.time == null ? '${to.day}T23:59' : to.param;
    final start = from.time == null ? '${from.day}T00:00' : from.param;
    return end.compareTo(start) < 0;
  }

  ActivityFilter _with({
    Object? from = _keep,
    Object? to = _keep,
    bool? everyone,
    Object? person = _keep,
  }) {
    final (uuid, name) = identical(person, _keep)
        ? (_draft.personUuid, _draft.personName)
        : (person as (String, String)?) ?? (null, null);

    return ActivityFilter(
      everyone: everyone ?? _draft.everyone,
      personUuid: uuid,
      personName: name,
      from: identical(from, _keep) ? _draft.from : from as ActivityMoment?,
      to: identical(to, _keep) ? _draft.to : to as ActivityMoment?,
    );
  }

  Future<void> _pickDay(bool start) async {
    final current = start ? _draft.from : _draft.to;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current?.day ?? '') ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final moment = ActivityMoment(dateParam(picked), current?.time);
    setState(() => _draft = start ? _with(from: moment) : _with(to: moment));
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _draft.from : _draft.to;
    // A time only narrows a day; without one there is nothing to narrow.
    if (current == null) return _pickDay(start);
    final parts = current.time?.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: parts == null
          ? TimeOfDay(hour: start ? 0 : 23, minute: start ? 0 : 59)
          : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    final moment = current.withTime(_hm(picked));
    setState(() => _draft = start ? _with(from: moment) : _with(to: moment));
  }

  Future<void> _pickPerson() async {
    final picked = await showModalBottomSheet<_Person>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PersonPicker(),
    );
    if (picked == null) return;
    setState(() {
      _draft = switch (picked) {
        _Me() => _with(everyone: false, person: null),
        _Everyone() => _with(everyone: true, person: null),
        _Someone(:final uuid, :final name) => _with(
          everyone: false,
          person: (uuid, name),
        ),
      };
    });
  }

  Widget _end(String label, bool start) {
    final moment = start ? _draft.from : _draft.to;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            onPressed: () => _pickDay(start),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              moment == null
                  ? '$label · ${tr('Any time')}'
                  : '$label · ${dayLabel(moment.day)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: () => _pickTime(start),
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(moment?.time ?? (start ? '00:00' : '23:59')),
          ),
        ),
        if (moment != null)
          IconButton(
            tooltip: tr('Clear'),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(
              () => _draft = start ? _with(from: null) : _with(to: null),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final personLabel = _draft.everyone
        ? tr('Everyone')
        : _draft.personName ?? tr('Only me');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.pageInset,
        0,
        AppTheme.pageInset,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Filters'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (widget.isAdmin) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(tr('Person')),
              subtitle: Text(personLabel),
              trailing: const Icon(Icons.expand_more),
              onTap: _pickPerson,
            ),
            const SizedBox(height: 8),
          ],
          _end(tr('From'), true),
          const SizedBox(height: 10),
          _end(tr('To'), false),
          if (_backwards) ...[
            const SizedBox(height: 10),
            Text(
              tr('The end cannot come before the start.'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _backwards
                ? null
                : () => Navigator.of(context).pop(_draft),
            child: Text(tr('Apply')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ActivityFilter.mine),
            child: Text(tr('Reset')),
          ),
        ],
      ),
    );
  }
}

const _keep = Object();

/// The person picker's answer.
sealed class _Person {
  const _Person();
}

class _Me extends _Person {
  const _Me();
}

class _Everyone extends _Person {
  const _Everyone();
}

class _Someone extends _Person {
  const _Someone(this.uuid, this.name);

  final String uuid;
  final String name;
}

/// Only me, everyone, or one account found by name or email.
class _PersonPicker extends StatefulWidget {
  const _PersonPicker();

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  Timer? _debounce;
  late Future<List<AdminUser>> _people = _search('');

  Future<List<AdminUser>> _search(String query) =>
      context.read<SpendLogRepository>().adminUsers(search: query.trim());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTheme.pageInset,
          0,
          AppTheme.pageInset,
          MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            TextField(
              autocorrect: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('Search by name or email'),
              ),
              // One request per pause in typing, not one per keystroke.
              onChanged: (query) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _people = _search(query));
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<AdminUser>>(
                future: _people,
                builder: (context, snapshot) {
                  final people = snapshot.data ?? const <AdminUser>[];

                  return ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(tr('Only me')),
                        onTap: () => Navigator.of(context).pop(const _Me()),
                      ),
                      ListTile(
                        leading: const Icon(Icons.public),
                        title: Text(tr('Everyone')),
                        onTap: () =>
                            Navigator.of(context).pop(const _Everyone()),
                      ),
                      const Divider(),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(apiErrorMessage(snapshot.error!)),
                        )
                      else if (people.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            tr('Nothing found.'),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        for (final person in people)
                          ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                person.name.isEmpty
                                    ? '?'
                                    : person.name[0].toUpperCase(),
                              ),
                            ),
                            title: Text(person.name),
                            subtitle: Text(person.email),
                            onTap: () =>
                                Navigator.of(context)
                                    .pop(_Someone(person.uuid, person.name)),
                          ),
                    ],
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

/// One line of the log, as the Activity screen and the Savings history tab
/// both draw it — shared so the two cannot drift into describing the same
/// record differently.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry, this.showUser = false});

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
    'borrowing' => Icons.handshake_outlined,
    'borrowing_repayment' => Icons.undo_rounded,
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
    const months = [
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    if (day == today) return '${tr('Today')} · $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return '${tr('Yesterday')} · $time';
    }

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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
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
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          ),
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
