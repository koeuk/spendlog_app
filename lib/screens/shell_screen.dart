import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/glass.dart';
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

/// Near enough to half the bar's height to read as a capsule at phone width,
/// without rounding so far that the outer tabs sit on the curve.
const _barRadius = 28.0;

/// The tab's own pill, sitting inside the bar's curve.
const _itemRadius = 22.0;

/// A frosted capsule holding the five tabs, floating clear of all four edges
/// with the content passing behind it.
///
/// A capsule rather than the full-width shelf it used to be: the bar is the
/// one piece of chrome on every screen, and letting the ground show around it
/// keeps it reading as something laid over the app rather than a floor the
/// app stands on. The blur is what sells it — a translucent bar with nothing
/// moving behind it is just a paler bar.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Outside the panel, so the capsule floats above the home indicator
    // rather than stretching its glass down into that strip.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: GlassPanel(
          strong: true,
          // Heavier than a sheet's: this sits over moving content the whole
          // time, and a light blur leaves it legible only on plain stretches.
          blur: 30,
          lifted: true,
          borderRadius: BorderRadius.circular(_barRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
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
    final accent = AppTheme.accent(context);
    // The active tab takes the accent rather than plain ink: over frosted
    // glass, weight alone stopped telling the five apart.
    final color = selected ? accent : AppTheme.faint(context, 0.50);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_itemRadius),
        child: AnimatedContainer(
          duration: _motion,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            // A wash of the accent, not the accent itself: a solid pill on
            // glass reads as a button sitting on the bar rather than the tab
            // the bar is showing.
            color: selected
                ? accent.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(_itemRadius),
          ),
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
                  tr(destination.label),
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
