import 'package:flutter/material.dart';

import '../theme.dart';

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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.savings_outlined, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.green),
            ),
          ],
        ),
      ),
    );
  }
}
