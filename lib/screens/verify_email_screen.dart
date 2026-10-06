import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';
import 'auth_shell.dart';

/// Where a signed-in account with an unconfirmed email is held: type the
/// 6-digit code the server mailed, or ask for a new one.
///
/// The router sends every unverified session here and nowhere else, so there
/// is no navigation on success — verifying replaces the user in
/// [AuthNotifier], and the redirect moves on into the app by itself.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  /// The server refuses a resend within a minute of the last code.
  static const _resendWait = Duration(seconds: 60);

  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  bool _verifying = false;
  bool _resending = false;
  String? _error;

  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();

    // Right after sign-up the first code is already on its way; start the
    // wait from then so "Resend" is not offered straight away.
    final sentAt = context.read<AuthNotifier>().verificationCodeSentAt;
    if (sentAt != null) {
      _startCountdown(_resendWait - DateTime.now().difference(sentAt));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(Duration remaining) {
    _ticker?.cancel();
    _secondsLeft = remaining.inSeconds.clamp(0, _resendWait.inSeconds);
    if (_secondsLeft == 0) return;

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();

      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    // Captured before the await: `context` must not be touched across one.
    final auth = context.read<AuthNotifier>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final message = await auth.verifyEmail(_code.text.trim());
      // No navigation here: the router redirects the moment the user flips to
      // verified. The messenger outlives this route, so the note survives it.
      if (message.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Could not verify the code.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _secondsLeft > 0) return;

    setState(() {
      _resending = true;
      _error = null;
    });

    final auth = context.read<AuthNotifier>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final message = await auth.resendVerificationCode();
      if (!mounted) return;

      _code.clear();
      setState(() => _startCountdown(_resendWait));
      if (message.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: 'Could not send a new code.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthNotifier, String>(
      (auth) => auth.state.user?.email ?? '',
    );

    return AuthShell(
      heading: tr('Verify your email'),
      description: tr(
        'We sent a 6-digit code to :email. Enter it below to confirm your email.',
      ).replaceAll(':email', email),
      footer: TextButton(
        onPressed: () => context.read<AuthNotifier>().signOut(),
        child: Text(tr('Sign out')),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CodeField(
              controller: _code,
              // The server's 422 on `code` (wrong, expired, out of guesses, too
              // soon to resend) sits right under the field it is about.
              errorText: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(tr('Verify')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: (_resending || _secondsLeft > 0) ? null : _resend,
              child: Text(
                _secondsLeft > 0
                    ? tr('Resend code in :seconds s')
                        .replaceAll(':seconds', '$_secondsLeft')
                    : tr('Resend code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
