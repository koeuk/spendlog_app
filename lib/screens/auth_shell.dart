import 'package:flutter/material.dart';

import '../theme.dart';

/// The shared frame for every signed-out screen: the logo, a heading, a
/// one-line description, then the form — centered, narrow, calm.
///
/// The mark carries the branding on its own. A wordmark above it *and* a
/// per-screen glyph below made three things competing for the top of a screen
/// whose only job is one short form.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.heading,
    required this.description,
    required this.child,
    this.footer,
  });

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
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.savings_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
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
