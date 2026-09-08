import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_provider.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/glass.dart';

void main() {
  runApp(const ProviderScope(child: SpendLogApp()));
}

class SpendLogApp extends ConsumerWidget {
  const SpendLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SpendLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      // One gradient ground beneath every route; scaffolds are transparent.
      builder: (context, child) => GlassBackdrop(child: child!),
    );
  }
}
