import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The ground every screen sits on: a soft gradient with a few large, blurred
/// colour blobs. Cards and inputs are translucent, so this is what shows
/// through them — without it the "glass" would be glass over nothing.
///
/// Installed once, in `MaterialApp.builder`, beneath the navigator, so every
/// route (signed-out screens included) shares the same ground and the
/// scaffolds themselves can stay transparent.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF0F120F), Color(0xFF161C17)]
                  : const [Color(0xFFF5F7F2), Color(0xFFEBF0E8)],
            ),
          ),
        ),
        _Blob(
          alignment: const Alignment(-1.3, -1.0),
          size: 440,
          color: AppTheme.green,
          alpha: isDark ? 0.28 : 0.18,
        ),
        _Blob(
          alignment: const Alignment(1.4, -0.15),
          size: 380,
          color: AppTheme.greenBright,
          alpha: isDark ? 0.18 : 0.16,
        ),
        _Blob(
          alignment: const Alignment(0.9, 1.3),
          size: 480,
          color: const Color(0xFFD9A441),
          alpha: isDark ? 0.10 : 0.12,
        ),
        child,
      ],
    );
  }
}

/// A radial fade rather than a blurred circle: same look, no filter to pay
/// for on every frame.
class _Blob extends StatelessWidget {
  const _Blob({
    required this.alignment,
    required this.size,
    required this.color,
    required this.alpha,
  });

  final Alignment alignment;
  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
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
