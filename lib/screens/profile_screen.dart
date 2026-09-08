import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/theme_provider.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// The Profile tab, laid out as a settings list: a header with who is signed
/// in, then labelled groups of rows. Anything that needs a form — editing the
/// account, changing the password — opens in a sheet so the list itself stays
/// a list you can scan.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTheme.pageInset, 8, AppTheme.pageInset, AppTheme.navBarClearance),
        children: [
          _Header(user: user, onTap: () => _showSheet(context, const _ProfileSheet())),
          _Section(
            title: 'General',
            rows: [
              _SettingsRow(
                icon: Icons.brightness_6_outlined,
                label: 'Appearance',
                value: _themeLabel(themeMode),
                onTap: () => _chooseTheme(context, ref, themeMode),
              ),
            ],
          ),
          _Section(
            title: 'Account',
            rows: [
              _SettingsRow(
                icon: Icons.person_outline,
                label: 'Edit profile',
                onTap: () => _showSheet(context, const _ProfileSheet()),
              ),
              _SettingsRow(
                icon: Icons.key_outlined,
                label: 'Change password',
                onTap: () => _showSheet(context, const _PasswordSheet()),
              ),
            ],
          ),
          _Section(
            rows: [
              _SettingsRow(
                icon: Icons.logout,
                label: 'Sign out',
                color: _danger,
                chevron: false,
                onTap: () => ref.read(authProvider.notifier).signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Auto',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _chooseTheme(BuildContext context, WidgetRef ref, ThemeMode current) async {
    final chosen = await _showSheet<ThemeMode>(context, _AppearanceSheet(current: current));

    if (chosen != null) ref.read(themeModeProvider.notifier).set(chosen);
  }
}

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showGlassSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// List pieces
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onTap});

  final User? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial =
        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?';

    return Card(
      shape: AppTheme.rowShape(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.green,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(fontSize: 12, color: AppTheme.faint(context, 0.5)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (user?.isAdmin ?? false) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surface,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: AppTheme.faint(context, 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled group: label above, one card with the rows stacked inside and a
/// hairline between each pair.
class _Section extends StatelessWidget {
  const _Section({this.title, required this.rows});

  final String? title;
  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.faint(context, 0.06);

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.faint(context, 0.5),
                ),
              ),
            ),
          ],
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: Divider(height: 1, thickness: 1, color: hairline),
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.color,
    this.chevron = true,
  });

  final IconData icon;
  final String label;

  /// Short current-state text shown before the chevron, e.g. "Dark".
  final String? value;
  final VoidCallback? onTap;

  /// Tints icon and label; used for destructive rows.
  final Color? color;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? AppTheme.faint(context, 0.6)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value!,
                  style: TextStyle(fontSize: 14, color: AppTheme.faint(context, 0.45)),
                ),
              ),
            if (chevron)
              Icon(Icons.chevron_right, size: 20, color: AppTheme.faint(context, 0.3)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets
// ---------------------------------------------------------------------------

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.faint(context, 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.current});

  final ThemeMode current;

  static const _options = [
    (ThemeMode.system, Icons.brightness_auto_outlined, 'Auto', 'Follow the system setting'),
    (ThemeMode.light, Icons.light_mode_outlined, 'Light', 'Always light'),
    (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark', 'Always dark'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Appearance',
      child: Column(
        children: [
          for (final (mode, icon, label, hint) in _options)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Icon(icon, size: 22, color: AppTheme.faint(context, 0.6)),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(hint,
                  style: TextStyle(fontSize: 12, color: AppTheme.faint(context, 0.45))),
              trailing: mode == current
                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );
  }
}

/// Owns its controllers and `ref` so it survives the list rebuilding under it.
class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  final _formKey = GlobalKey<FormState>();

  User? get _user => ref.read(authProvider).user;

  late final _name = TextEditingController(text: _user?.name ?? '');
  late final _username = TextEditingController(text: _user?.username ?? '');
  late final _email = TextEditingController(text: _user?.email ?? '');

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = await ref.read(repositoryProvider).updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
            username: _username.text.trim(),
          );

      ref.read(authProvider.notifier).setUser(user);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, fallback: 'Could not save the profile.'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Edit profile',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(hintText: 'Username (optional)'),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(hintText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email.' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const _Spinner() : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _show = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await ref.read(repositoryProvider).changePassword(
            password: _password.text,
            passwordConfirmation: _confirm.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password changed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiErrorMessage(e, fallback: 'Could not change the password.'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Change password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _password,
              obscureText: !_show,
              decoration: InputDecoration(
                hintText: 'New password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _show = !_show),
                  icon: Icon(
                    _show ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: !_show,
              decoration: const InputDecoration(hintText: 'Confirm new password'),
              validator: (v) => v != _password.text ? 'Passwords do not match.' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const _Spinner() : const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
