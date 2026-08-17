import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// The signed-in frame: one bottom bar, four tabs, each tab keeping its own
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
        onSelected: (index) => navigationShell.goBranch(
          index,
          // Re-tapping the active tab pops it back to its root — the platform
          // convention.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

typedef _Destination = ({IconData icon, IconData active, String label});

const _destinations = <_Destination>[
  (icon: Icons.grid_view_outlined, active: Icons.grid_view_rounded, label: 'Dashboard'),
  (icon: Icons.receipt_long_outlined, active: Icons.receipt_long_rounded, label: 'Expenses'),
  (icon: Icons.savings_outlined, active: Icons.savings_rounded, label: 'Budgets'),
  (icon: Icons.person_outline, active: Icons.person_rounded, label: 'Profile'),
];

const _radius = 30.0;
const _motion = Duration(milliseconds: 320);

/// A detached, translucent pill holding the four tabs. Only the active tab
/// carries its label — it widens to make room, so the bar reads as one moving
/// shape rather than four static captions.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: DecoratedBox(
          // Outside the clip, or the blur below would cut the shadow off.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        _NavItem(
                          destination: _destinations[i],
                          selected: i == currentIndex,
                          onTap: () => onSelected(i),
                        ),
                    ],
                  ),
                ),
              ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: _motion,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.green : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: _motion,
                child: Icon(
                  selected ? destination.active : destination.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? Colors.white : Colors.black.withValues(alpha: 0.45),
                ),
              ),
              // Slides the label out from behind the icon. Clipped so it
              // occupies no width at all while the tab is inactive.
              ClipRect(
                child: AnimatedAlign(
                  duration: _motion,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: selected ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 72),
                      child: Text(
                        destination.label,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
