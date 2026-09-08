import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// The Menu tab's sheet: everything that is not one of the four main tabs,
/// as one scannable list. Admin rows only appear for admins — the server
/// gates them too, so hiding them is a courtesy, not the security.
Future<void> showMenuSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) => const _MenuSheet(),
  );
}

typedef _Entry = ({IconData icon, String label, String path, bool admin});

const _entries = <_Entry>[
  (
    icon: Icons.savings_outlined,
    label: 'Savings',
    path: '/savings',
    admin: false,
  ),
  (
    icon: Icons.payments_outlined,
    label: 'Income',
    path: '/income',
    admin: false,
  ),
  (
    icon: Icons.category_outlined,
    label: 'Categories',
    path: '/profile/categories',
    admin: false,
  ),
  (
    icon: Icons.history,
    label: 'Activity log',
    path: '/profile/activity',
    admin: false,
  ),
  // The account page: photo, details, appearance, password — and, for
  // admins, the door to the app-wide settings.
  (
    icon: Icons.settings_outlined,
    label: 'Settings',
    path: '/profile',
    admin: false,
  ),
  (
    icon: Icons.group_outlined,
    label: 'Users',
    path: '/profile/admin-users',
    admin: true,
  ),
];

class _MenuSheet extends ConsumerWidget {
  const _MenuSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(
      authProvider.select((s) => s.user?.isAdmin ?? false),
    );
    final rows = _entries.where((e) => isAdmin || !e.admin).toList();
    final hairline = AppTheme.faint(context, 0.06);

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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Menu',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            // Rows sit straight on the glass, a hairline between each pair.
            // A card around them made a box inside a box.
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 42),
                  child: Divider(height: 1, thickness: 1, color: hairline),
                ),
              _MenuRow(
                entry: rows[i],
                onTap: () {
                  // Close first, then go: the sheet lives above the shell's
                  // navigator, so leaving it open would strand it over the
                  // new screen.
                  Navigator.of(context).pop();
                  context.go(rows[i].path);
                },
              ),
            ],
            // A quick theme flip lives here as well as in Settings, so it is
            // one tap from anywhere; the sheet stays open to show the change.
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Divider(height: 1, thickness: 1, color: hairline),
            ),
            const _ThemeRow(),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry, required this.onTap});

  final _Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            Icon(entry.icon, size: 22, color: ink.withValues(alpha: 0.75)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                entry.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.faint(context, 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark mode on or off. "Auto" counts as whatever the system currently
/// shows, and flipping the switch pins the choice; Settings still offers
/// Auto for anyone who wants it back.
class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 22,
            color: ink.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Dark mode',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.green,
            onChanged: (on) => ref
                .read(themeModeProvider.notifier)
                .set(on ? ThemeMode.dark : ThemeMode.light),
          ),
        ],
      ),
    );
  }
}
