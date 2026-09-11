import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../api/api_client.dart';
import '../repositories/auth_repository.dart';
import 'auth_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _email.text.trim();
    // Captured before the await: `context` must not be touched across one.
    final repository = context.read<AuthRepository>();

    try {
      await repository.requestResetCode(email);

      if (mounted) {
        context.go('/reset-password?email=${Uri.encodeComponent(email)}');
      }
    } catch (e) {
      setState(
        () => _error = apiErrorMessage(e, fallback: 'Could not send the code.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      heading: tr('Forgot your password?'),
      description: "No problem. Tell us your email address and we'll send you a 6-digit code to choose a new one.",
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: Text(tr('Back to sign in')),
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
              controller: _email,
              decoration: InputDecoration(hintText: tr('Email')),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your email.' : null,
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
                  : Text(tr('Email me a code')),
            ),
          ],
        ),
      ),
    );
  }
}
