import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/theme_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        // A tab root, so nothing is beneath it to pop to — yet it is reached
        // from the Menu sheet like a pushed page, and reads as one. Back goes
        // home, which is where the sheet was most likely opened from.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pageInset,
          8,
          AppTheme.pageInset,
          AppTheme.navBarClearance,
        ),
        children: [
          _Header(user: user),
          _Section(
            title: 'General',
            rows: [
              _SettingsRow(
                icon: Icons.brightness_6_outlined,
                label: 'Appearance',
                value: _themeLabel(themeMode),
                onTap: () => _chooseTheme(context, ref, themeMode),
              ),
              // App-wide settings (exchange rate, FAQ) are admin-only; the
              // server gates the page too, this just keeps the row honest.
              if (isAdmin)
                _SettingsRow(
                  icon: Icons.tune,
                  label: 'App settings',
                  onTap: () => context.go('/profile/admin-settings'),
                ),
            ],
          ),
          _Section(
            title: 'Account',
            rows: [
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

  Future<void> _chooseTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final chosen = await _showSheet<ThemeMode>(
      context,
      _AppearanceSheet(current: current),
    );

    if (chosen != null) ref.read(themeModeProvider.notifier).set(chosen);
  }
}

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showGlassSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// List pieces
// ---------------------------------------------------------------------------

/// The portrait: photo (or initial) with a camera badge that changes it,
/// the name beneath, and an ADMIN chip where it applies. Details live in the
/// rows below rather than crowding the picture.
class _Header extends ConsumerStatefulWidget {
  const _Header({required this.user});

  final User? user;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  bool _busy = false;

  Future<void> _photoMenu() async {
    final user = widget.user;
    final action = await _showSheet<String>(
      context,
      _SheetFrame(
        title: 'Profile photo',
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(
                Icons.photo_outlined,
                color: AppTheme.faint(context, 0.6),
              ),
              title: Text(
                user?.avatarUrl == null ? 'Choose a photo' : 'Change photo',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(context).pop('change'),
            ),
            if (user?.avatarUrl != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(
                  Icons.delete_outline,
                  color: ProfileScreen._danger,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ProfileScreen._danger,
                  ),
                ),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    setState(() => _busy = true);
    try {
      if (action == 'change') {
        await _pickAndUploadPhoto(context, ref);
      } else {
        await _removePhoto(context, ref);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final surface = Theme.of(context).colorScheme.surface;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.glassFill(context),
                  border: Border.all(color: AppTheme.glassBorder(context)),
                ),
                child: UserAvatar(user: user, size: 96, circle: true),
              ),
              // The camera badge sits on the rim, the way every profile
              // screen's does, so it reads as "edit the picture".
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppTheme.accent(context),
                  shape: CircleBorder(
                    side: BorderSide(color: surface, width: 3),
                  ),
                  child: InkWell(
                    onTap: _busy ? null : _photoMenu,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.photo_camera_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // The pencil is the one obvious way in to the edit sheet; the rows
          // below open it too, but a name with nothing beside it reads as
          // fixed.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user?.name ?? '',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: AppTheme.glassFill(context),
                shape: CircleBorder(
                  side: BorderSide(color: AppTheme.glassBorder(context)),
                ),
                child: InkWell(
                  onTap: () => _showSheet(context, const _ProfileSheet()),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (user?.isAdmin ?? false) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'ADMIN',
                style: TextStyle(
                  color: surface,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Photo changes save on their own, the moment one is picked — they do not
/// wait for the edit sheet's "Save changes", which validates the text fields
/// and would hold a perfectly good photo hostage to a blank name. Shared by
/// the portrait's badge and the edit sheet.
Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Downscaled on the device: the server caps uploads at 4 MB and shows
      // the photo at 96px at most, so a full camera frame is waste on both ends.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
  } catch (_) {
    // No picker on this platform build (a desktop run that predates the
    // plugin, say): a message beats an uncaught exception.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo picker.')),
      );
    }
    return;
  }
  if (picked == null || !context.mounted) return;

  // A non-null copy: the closure below cannot see the null check's promotion.
  final file = picked;

  await _applyPhoto(
    context,
    ref,
    () async => ref
        .read(repositoryProvider)
        .uploadAvatar(bytes: await file.readAsBytes(), filename: file.name),
  );
}

Future<void> _removePhoto(BuildContext context, WidgetRef ref) => _applyPhoto(
  context,
  ref,
  () => ref.read(repositoryProvider).removeAvatar(),
);

Future<void> _applyPhoto(
  BuildContext context,
  WidgetRef ref,
  Future<User> Function() call,
) async {
  try {
    ref.read(authProvider.notifier).setUser(await call());
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          apiErrorMessage(e, fallback: 'Could not update the photo.'),
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
            // Solid, not glass: rows of small text read better on an opaque
            // pane, and the portrait above already shows the ground.
            color: AppTheme.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
            const SizedBox(width: 12),
            const Spacer(),
            if (value != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.faint(context, 0.45),
                    ),
                  ),
                ),
              ),
            if (chevron)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTheme.faint(context, 0.3),
              ),
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
              style: Theme.of(context).textTheme.titleLarge
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
    (
      ThemeMode.system,
      Icons.brightness_auto_outlined,
      'Auto',
      'Follow the system setting',
    ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(
                icon,
                size: 22,
                color: AppTheme.faint(context, 0.6),
              ),
              title: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.faint(context, 0.45),
                ),
              ),
              trailing: mode == current
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
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
  late final _phone = TextEditingController(text: _user?.phone ?? '');

  bool _saving = false;
  bool _photoBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() =>
      _withPhotoBusy(() => _pickAndUploadPhoto(context, ref));

  Future<void> _removePhotoFromSheet() =>
      _withPhotoBusy(() => _removePhoto(context, ref));

  Future<void> _withPhotoBusy(Future<void> Function() call) async {
    setState(() => _photoBusy = true);
    try {
      await call();
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = await ref
          .read(repositoryProvider)
          .updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
            username: _username.text.trim(),
            phone: _phone.text.trim(),
          );

      ref.read(authProvider.notifier).setUser(user);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Could not save the profile.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched, not read: the box below must repaint the moment a photo lands.
    final user = ref.watch(authProvider).user;

    return _SheetFrame(
      title: 'Edit profile',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(user: user, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _photoBusy ? null : _changePhoto,
                        icon: _photoBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_outlined, size: 18),
                        label: Text(
                          user?.avatarUrl == null
                              ? 'Add photo'
                              : 'Change photo',
                        ),
                      ),
                      if (user?.avatarUrl != null)
                        TextButton(
                          onPressed: _photoBusy ? null : _removePhotoFromSheet,
                          style: TextButton.styleFrom(
                            foregroundColor: ProfileScreen._danger,
                          ),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                hintText: 'Username (optional)',
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(hintText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your email.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(hintText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
              autocorrect: false,
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
      await ref
          .read(repositoryProvider)
          .changePassword(
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
          content: Text(
            apiErrorMessage(e, fallback: 'Could not change the password.'),
          ),
        ),
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
                    _show
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'At least 8 characters.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: !_show,
              decoration: const InputDecoration(
                hintText: 'Confirm new password',
              ),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match.' : null,
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
