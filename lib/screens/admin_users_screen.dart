import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models/admin.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// User management, mirroring the web's Users screen: list, create, edit,
/// suspend, delete. The API refuses non-admins regardless of what this UI
/// shows, so hiding it for them is courtesy, not security.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = context.watch<AdminUsersNotifier>().state;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Users'))),
      floatingActionButton: AddPill(
        label: tr('Add'),
        icon: Icons.person_add_alt,
        onPressed: () => _UserFormPage.open(context),
      ),
      body: users.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => context.read<AdminUsersNotifier>().invalidate(),
        ),
        data: (list) => RefreshIndicator(
          color: AppTheme.accent(context),
          // `refresh` never throws — see AsyncNotifier.refresh.
          onRefresh: () => context.read<AdminUsersNotifier>().refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              8,
              AppTheme.pageInset,
              AppTheme.navBarClearance + 72,
            ),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = list[index];

              return Card(
                shape: AppTheme.rowShape(context),
                child: InkWell(
                  onTap: () => _UserFormPage.open(context, user: user),
                  borderRadius: BorderRadius.circular(AppTheme.rowRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        _UserAvatar(user: user, size: 42),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.faint(context, 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Badge(
                          text: user.role,
                          color: user.role == 'user'
                              ? const Color(0xFF64748B)
                              : AppTheme.accent(context),
                        ),
                        if (user.status != 'active') ...[
                          const SizedBox(width: 6),
                          _Badge(
                            text: user.status,
                            color: const Color(0xFFDC2626),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _UserFormPage extends StatefulWidget {
  const _UserFormPage({this.user});

  final AdminUser? user;

  static Future<void> open(BuildContext context, {AdminUser? user}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _UserFormPage(user: user),
      ),
    );
  }

  @override
  State<_UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<_UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _username = TextEditingController(
    text: widget.user?.username ?? '',
  );
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  final _password = TextEditingController();

  late String _role = widget.user?.role ?? 'user';
  late String _status = widget.user?.status ?? 'active';
  bool _busy = false;
  String? _error;

  bool get _editing => widget.user != null;

  /// The row as last returned by the server, so the photo box repaints the
  /// moment an upload lands without waiting for the list to refresh.
  late AdminUser? _current = widget.user;
  bool _photoBusy = false;

  /// Photos save on their own, the moment one is picked — they do not wait
  /// for "Save changes", which validates the text fields.
  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Read before the upload: `context` must not be touched across an await.
    final repository = context.read<SpendLogRepository>();

    await _updatePhoto(
      () async => repository.uploadAdminUserAvatar(
        widget.user!.uuid,
        bytes: await picked.readAsBytes(),
        filename: picked.name,
      ),
    );
  }

  Future<void> _removePhoto() {
    final repository = context.read<SpendLogRepository>();

    return _updatePhoto(
      () => repository.removeAdminUserAvatar(widget.user!.uuid),
    );
  }

  Future<void> _updatePhoto(Future<AdminUser> Function() call) async {
    setState(() => _photoBusy = true);

    // Captured before the call, so a page left mid-upload still drops the
    // stale list.
    final refresh = context.read<AdminUsersNotifier>().invalidate;

    try {
      final updated = await call();
      refresh();
      if (!mounted) return;
      setState(() => _current = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Could not update the photo.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Both captured before the write: `context` must not be touched across an
    // await, and the refresh must still land if this page is gone by then.
    final repository = context.read<SpendLogRepository>();
    final refresh = context.read<AdminUsersNotifier>().invalidate;

    try {
      await repository.saveAdminUser(
        uuid: widget.user?.uuid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        role: _role,
        status: _status,
      );

      refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(
        () => _error = apiErrorMessage(e, fallback: 'Could not save the user.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Delete this user?')),
        content: Text('${widget.user!.name} — their expenses go with them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Captured before the delete — see _save.
    final repository = context.read<SpendLogRepository>();
    final refresh = context.read<AdminUsersNotifier>().invalidate;

    try {
      await repository.deleteAdminUser(widget.user!.uuid);

      refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit user' : 'Add a user'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: tr('Delete'),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            8,
            AppTheme.pageInset,
            40,
          ),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.errorFill(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.errorInk(context),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_editing) ...[
              _PhotoBlock(
                user: _current,
                busy: _photoBusy,
                onChange: _changePhoto,
                onRemove: _removePhoto,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              decoration: InputDecoration(hintText: tr('Name')),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: InputDecoration(hintText: tr('Username (optional)')),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(hintText: tr('Email')),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter an email.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                hintText: _editing
                    ? 'New password (blank keeps it)'
                    : 'Password',
              ),
              validator: (v) {
                if (!_editing && (v == null || v.length < 8)) {
                  return 'At least 8 characters.';
                }
                if (_editing && v != null && v.isNotEmpty && v.length < 8) {
                  return 'At least 8 characters.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            Eyebrow(tr('Role')),
            SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'user', label: Text(tr('User'))),
                ButtonSegment(value: 'admin', label: Text(tr('Admin'))),
              ],
              selected: {_role},
              onSelectionChanged: (selection) =>
                  setState(() => _role = selection.first),
              showSelectedIcon: false,
            ),
            SizedBox(height: 16),
            Eyebrow(tr('Status')),
            SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'active', label: Text(tr('Active'))),
                ButtonSegment(value: 'suspended', label: Text(tr('Suspended'))),
                ButtonSegment(value: 'archived', label: Text(tr('Archived'))),
              ],
              selected: {_status},
              onSelectionChanged: (selection) =>
                  setState(() => _status = selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_editing ? 'Save changes' : 'Create user'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The user's photo, or their initial on a soft green tile while there is
/// none (or while the photo fails to load).
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, required this.size});

  final AdminUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final url = user?.avatarUrl;

    final fallback = Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppTheme.accent(context),
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.accent(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Photo controls at the top of the edit page: the picture, then change and
/// remove. Saves independently of the form below.
class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.user,
    required this.busy,
    required this.onChange,
    required this.onRemove,
  });

  final AdminUser? user;
  final bool busy;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: AppTheme.rowShape(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            _UserAvatar(user: user, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : onChange,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_outlined, size: 18),
                    label: Text(
                      user?.avatarUrl == null ? 'Add photo' : 'Change photo',
                    ),
                  ),
                  if (user?.avatarUrl != null)
                    TextButton(
                      onPressed: busy ? null : onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      child: Text(tr('Remove')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
