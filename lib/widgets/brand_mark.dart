import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/branding_provider.dart';
import '../theme.dart';

/// The app's mark: the uploaded logo when there is one, on a white tile so
/// any logo reads; otherwise the stock piggy on the accent colour.
class BrandMark extends ConsumerWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(brandingProvider.select((b) => b.logoUrl));
    final radius = BorderRadius.circular(size * 0.31);

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppTheme.accent(context), borderRadius: radius),
      child: Icon(Icons.savings_outlined, color: AppTheme.onAccent(context), size: size / 2),
    );

    if (logo == null) return fallback;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: AppTheme.faint(context, 0.08)),
      ),
      child: Image.network(
        logo,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.savings_outlined,
          color: AppTheme.accent(context),
          size: size / 2,
        ),
      ),
    );
  }
}

/// Stock-safe read of the app name for titles.
String brandName(WidgetRef ref) => ref.watch(brandingProvider.select((b) => b.name));
