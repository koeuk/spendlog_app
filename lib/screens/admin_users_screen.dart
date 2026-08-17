import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/admin.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../widgets/common.dart';

/// User management, mirroring the web's Users screen: list, create, edit,
/// suspend, delete. The API refuses non-admins regardless of what this UI
/// shows, so hiding it for them is courtesy, not security.
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Users',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _UserFormPage.open(context),
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add'),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(adminUsersProvider),
        ),
        data: (list) => RefreshIndicator(
          color: AppTheme.green,
          onRefresh: () => refreshQuietly(ref.refresh(adminUsersProvider.future)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, AppTheme.navBarClearance + 72),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = list[index];

              return Card(
                child: InkWell(
                  onTap: () => _UserFormPage.open(context, user: user),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppTheme.green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Badge(
                          text: user.role,
                          color: user.role == 'user' ? const Color(0xFF64748B) : AppTheme.green,
                        ),
                        if (user.status != 'active') ...[
                          const SizedBox(width: 6),
                          _Badge(text: user.status, color: const Color(0xFFDC2626)),
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
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _UserFormPage extends ConsumerStatefulWidget {
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
  ConsumerState<_UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<_UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _username = TextEditingController(text: widget.user?.username ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  final _password = TextEditingController();

  late String _role = widget.user?.role ?? 'user';
  late String _status = widget.user?.status ?? 'active';
  bool _busy = false;
  String? _error;

  bool get _editing => widget.user != null;

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

    try {
      await ref.read(repositoryProvider).saveAdminUser(
            uuid: widget.user?.uuid,
            name: _name.text.trim(),
            email: _email.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
            role: _role,
            status: _status,
          );

      if (mounted) {
        ref.invalidate(adminUsersProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not save the user.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this user?'),
        content: Text('${widget.user!.name} — their expenses go with them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider).deleteAdminUser(widget.user!.uuid);

      if (mounted) {
        ref.invalidate(adminUsersProvider);
        Navigator.of(context).pop();
      }
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
        title: Text(
          _editing ? 'Edit user' : 'Add a user',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
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
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter an email.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                hintText: _editing ? 'New password (blank keeps it)' : 'Password',
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
            const Eyebrow('Role'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'user', label: Text('User')),
                ButtonSegment(value: 'admin', label: Text('Admin')),
              ],
              selected: {_role},
              onSelectionChanged: (selection) => setState(() => _role = selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            const Eyebrow('Status'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'suspended', label: Text('Suspended')),
                ButtonSegment(value: 'archived', label: Text('Archived')),
              ],
              selected: {_status},
              onSelectionChanged: (selection) => setState(() => _status = selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_editing ? 'Save changes' : 'Create user'),
            ),
          ],
        ),
      ),
    );
  }
}
