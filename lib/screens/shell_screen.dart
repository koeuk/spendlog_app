import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import 'menu_sheet.dart';

/// The signed-in frame: one bottom bar, five tabs, each tab keeping its own
/// navigation state via the router's indexed stack.
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar floats clear of the edges, so the tabs' content runs the full
      // height and passes beneath it. Scrollables pad themselves by
      // [AppTheme.navBarClearance] so nothing comes to rest underneath.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) {
          // The last tab is not a destination: it opens the menu sheet, and
          // its branch is only ever entered from a row in that sheet.
          if (index == _menuIndex) {
            showMenuSheet(context);
            return;
          }
          navigationShell.goBranch(
            index,
            // Re-tapping the active tab pops it back to its root — the
            // platform convention.
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

typedef _Destination = ({IconData icon, IconData active, String label});

const _destinations = <_Destination>[
  (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
  (
    icon: Icons.receipt_long_outlined,
    active: Icons.receipt_long_rounded,
    label: 'Expenses',
  ),
  (
    icon: Icons.savings_outlined,
    active: Icons.savings_rounded,
    label: 'Budgets',
  ),
  (
    icon: Icons.insights_outlined,
    active: Icons.insights_rounded,
    label: 'Reports',
  ),
  (icon: Icons.menu_rounded, active: Icons.menu_rounded, label: 'Menu'),
];

/// The Menu tab: opens a sheet rather than switching branch. It still lights
/// up while the profile branch beneath it is showing, since every row in the
/// sheet leads there.
const _menuIndex = 4;

const _iconSize = 24.0;

const _motion = Duration(milliseconds: 200);

/// A flat white bar holding the five tabs, each an icon over its label.
/// Nothing sits behind the active tab — it is simply drawn in ink while the
/// rest fall back to grey, so the bar stays calm and reads at a glance.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A plain rectangle, like the reference: no rounding anywhere, just a
    // hairline along the top where the bar meets the frosted shelf. The safe
    // area sits inside, so the bar's colour fills the home-indicator strip.
    return Material(
      color: AppTheme.surface(context),
      shape: Border(
        top: BorderSide(color: AppTheme.faint(context, isDark ? 0.12 : 0.08)),
      ),
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : AppTheme.faint(context, 0.50);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _iconSize + 2,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: _motion,
                    child: Icon(
                      selected ? destination.active : destination.icon,
                      key: ValueKey(selected),
                      size: _iconSize,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: _motion,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
