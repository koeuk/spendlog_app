/// Awaits a provider refresh without letting a failure escape.
///
/// `RefreshIndicator` discards the future its `onRefresh` returns, so an error
/// completing there surfaces as an *unhandled* exception — noise in debug, a
/// reported crash once `runApp` is wrapped for error reporting. The provider
/// already carries the failure in its own `AsyncError` state, which the screen
/// renders, so there is nothing left to do with it here.
Future<void> refreshQuietly(Future<Object?> refresh) async {
  try {
    await refresh;
  } catch (_) {
    // Deliberately swallowed — see above.
  }
}
