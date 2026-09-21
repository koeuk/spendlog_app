import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../api/api_client.dart';
import '../providers/auth_provider.dart';
import 'auth_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Captured before the await: `context` must not be touched across one.
    final auth = context.read<AuthNotifier>();

    try {
      await auth.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      // No navigation here: the router redirects the moment auth state flips.
    } catch (e) {
      setState(
        () => _error = apiErrorMessage(e, fallback: 'Could not create your account.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      heading: tr('Create your account'),
      description: tr('A few details and you can start tracking your spending.'),
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: Text(tr('Already have an account? Sign in')),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            TextFormField(
              controller: _name,
              decoration: InputDecoration(hintText: tr('Name')),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(hintText: tr('Email')),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your email.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                hintText: tr('Password'),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.length < 8)
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: !_showPassword,
              decoration: InputDecoration(hintText: tr('Confirm password')),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v != _password.text) ? 'The passwords do not match.' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(tr('Create account')),
            ),
          ],
        ),
      ),
    );
  }
}
