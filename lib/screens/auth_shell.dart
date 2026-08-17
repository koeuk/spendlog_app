import 'package:flutter/material.dart';

import '../theme.dart';

/// The shared frame for every signed-out screen, mirroring the web's auth
/// card: icon in a soft green tile, heading, one-line description, then the
/// form — centered, narrow, calm.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.icon,
    required this.heading,
    required this.description,
    required this.child,
    this.footer,
  });

  final IconData icon;
  final String heading;
  final String description;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.green,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.savings_outlined, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SpendLog',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.greenBright.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: AppTheme.greenBright, size: 26),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withValues(alpha: 0.55),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  child,
                  if (footer != null) ...[
                    const SizedBox(height: 24),
                    Center(child: footer),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
