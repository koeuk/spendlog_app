import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_mark.dart';

/// Shown only while the stored token is being confirmed against /me.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The logo alone, large: a splash is the one place it is the
            // whole picture, so no tile around it and room to breathe.
            const BrandMark(size: 120, bare: true),
            const SizedBox(height: 32),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.accent(context)),
            ),
          ],
        ),
      ),
    );
  }
}
