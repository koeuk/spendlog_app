import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ApiClient.instance),
);

/// The app's one source of truth for "who is signed in".
///
/// null while restoring the stored token at startup, then either a User or a
/// signed-out marker. The router redirects off this, so login and logout are
/// just state changes — no manual navigation calls.
class AuthState {
  const AuthState({this.user, this.restoring = false});

  final User? user;
  final bool restoring;

  bool get signedIn => user != null;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // A token revoked mid-session (from the web's token list, say) must land
    // the user back on login rather than leaving every screen showing
    // "Unauthenticated." with no way out.
    final subscription =
        ApiClient.instance.onUnauthorized.listen((_) => _dropSession());
    ref.onDispose(subscription.cancel);

    _restore();

    return const AuthState(restoring: true);
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Signed out *by the server*, so unlike [signOut] there is nothing to
  /// revoke — the interceptor has already dropped the dead token.
  void _dropSession() {
    if (state.signedIn || state.restoring) state = const AuthState();
  }

  /// How long the splash is held at launch.
  ///
  /// The token check usually finishes in milliseconds — instantly when there is
  /// nothing stored — so without this the brand screen flashes past in a single
  /// frame, which reads as a glitch rather than a launch.
  static const _splashHold = Duration(seconds: 3);

  /// A stored token from a previous run is only trusted after /me confirms it
  /// still works — it may have been revoked from the web's token list.
  ///
  /// The hold runs *alongside* the check rather than before it, so the splash
  /// lasts however long the slower of the two takes — never their sum. A slow
  /// network already has the user waiting; it should not also owe them three
  /// seconds.
  Future<void> _restore() async {
    final held = Future<void>.delayed(_splashHold);
    final restored = await _resolveSession();

    await held;

    state = restored;
  }

  Future<AuthState> _resolveSession() async {
    final token = await ApiClient.instance.readToken();

    if (token == null) return const AuthState();

    try {
      return AuthState(user: await _repository.me());
    } catch (_) {
      await ApiClient.instance.clearToken();

      return const AuthState();
    }
  }

  Future<void> signIn(String email, String password) async {
    state = AuthState(user: await _repository.login(email, password));
  }

  Future<void> signOut() async {
    await _repository.logout();
    state = const AuthState();
  }

  /// Called after a profile edit so the whole app shows the new details
  /// without waiting for the next /me.
  void setUser(User user) {
    state = AuthState(user: user);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
