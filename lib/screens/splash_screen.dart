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
            const BrandMark(size: 64),
            const SizedBox(height: 24),
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
