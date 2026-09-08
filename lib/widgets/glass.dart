import 'dart:ui';

import 'package:flutter/material.dart';

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

    return ColoredBox(
      color: isDark ? darkGround : lightGround,
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
    this.borderRadius = const BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
    this.blur = 22,
    this.strong = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// A more opaque tint, for panels that carry forms.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
