import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/branding_provider.dart';
import '../theme.dart';

/// The app's mark: the uploaded logo when there is one, on a white tile so
/// any logo reads; otherwise the stock piggy on the accent colour.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.bare = false});

  final double size;

  /// Draw the uploaded logo on its own — no tile, padding or border — for
  /// places like the splash where it is the whole picture and a box around
  /// it reads as a card. The stock fallback keeps its tile either way, since
  /// the tile *is* that mark.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    // `select`, not `watch`: the mark redraws only when the logo itself
    // changes, not when an admin moves the accent colour.
    final logo = context.select<BrandingNotifier, String?>(
      (branding) => branding.state.logoUrl,
    );
    final radius = BorderRadius.circular(size * 0.31);

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.accent(context),
        borderRadius: radius,
      ),
      child: Icon(
        Icons.savings_outlined,
        color: AppTheme.onAccent(context),
        size: size / 2,
      ),
    );

    if (logo == null) return fallback;

    final image = Image.network(
      logo,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        Icons.savings_outlined,
        color: AppTheme.accent(context),
        size: size / 2,
      ),
    );

    if (bare) return SizedBox(width: size, height: size, child: image);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: AppTheme.faint(context, 0.08)),
      ),
      child: image,
    );
  }
}

/// Stock-safe read of the app name for titles.
String brandName(BuildContext context) =>
    context.select<BrandingNotifier, String>((branding) => branding.state.name);
