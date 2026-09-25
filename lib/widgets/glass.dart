import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/branding.dart';
import '../providers/branding_provider.dart';
import '../theme.dart';

/// The ground every screen sits on: flat and neutral, the way Telegram's
/// settings and chat list are — light grey by day, near-black at night.
/// Cards and inputs are translucent panes over it, so the tone here is what
/// gives them their slight tint.
///
/// Installed once, in `MaterialApp.builder`, beneath the navigator, so every
/// route (signed-out screens included) shares the same ground and the
/// scaffolds themselves can stay transparent.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  /// Telegram's light background by day; the app's own near-black at night.
  static const lightGround = Color(0xFFEFF2F5);
  static const darkGround = AppTheme.darkGround;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final branding = context.watch<BrandingNotifier>().state;

    // A chosen background paints flat, as on the web. Light mode only: an
    // admin picking Cream should not switch dark mode off for everyone.
    final chosen = branding.plainBackground
        ? Branding.parseHex(branding.bodyColor)
        : null;

    return ColoredBox(
      color: isDark ? darkGround : (chosen ?? lightGround),
      child: child,
    );
  }
}

/// A frosted panel: blurs whatever scrolls beneath it, then tints it. Used
/// where content really does pass behind — the nav bar and modal sheets.
/// Static cards get the translucent fill without the blur, which reads the
/// same over the backdrop and costs nothing.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppTheme.cardRadius),
    ),
    this.blur = 22,
    this.strong = false,
    this.lifted = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// A more opaque tint, for panels that carry forms.
  final bool strong;

  /// A soft shadow beneath, for a pane that floats clear of every edge rather
  /// than meeting one. Without it a capsule over a pale ground has nothing to
  /// separate it from the content passing behind.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final panel = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.glassFill(context, strong: strong),
            borderRadius: borderRadius,
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: child,
        ),
      ),
    );

    if (!lifted) return panel;

    // Cast outside the clip, so the blur is not asked to render it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.44 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: panel,
    );
  }
}

/// The app's modal bottom sheet: frosted, rounded at the top, a hairline
/// where it meets the dimmed content. Replaces `showModalBottomSheet` so no
/// screen has to repeat the shape and colour.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (context) => GlassPanel(
      strong: true,
      blur: 28,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: builder(context),
    ),
  );
}

/// A segmented control on glass, for an `AppBar`'s `bottom` over a
/// [TabBarView].
///
/// A sliding capsule rather than Material's underline: the bar it sits in is
/// transparent, so an underline had nothing to rule off against, and the
/// shape matches the nav bar at the other end of the screen.
class GlassTabBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassTabBar({super.key, required this.controller, required this.tabs});

  final TabController controller;

  /// The labels, already translated.
  final List<String> tabs;

  static const _height = 44.0;
  static const _gap = 10.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height + _gap);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(99);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageInset,
        0,
        AppTheme.pageInset,
        _gap,
      ),
      child: GlassPanel(
        strong: true,
        blur: 24,
        borderRadius: radius,
        child: SizedBox(
          height: _height,
          child: TabBar(
            controller: controller,
            indicator: BoxDecoration(
              color: AppTheme.accent(context),
              borderRadius: radius,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            // Inset, so the capsule sits inside the track rather than
            // covering its edge.
            indicatorPadding: const EdgeInsets.all(4),
            dividerColor: Colors.transparent,
            splashBorderRadius: radius,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.faint(context, 0.55),
            labelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            tabs: [for (final label in tabs) Tab(height: _height, text: label)],
          ),
        ),
      ),
    );
  }
}
