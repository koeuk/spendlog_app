import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/spendlog_repository.dart';

/// The three states a server-backed value can be in, as one value.
///
/// Hand-rolled rather than imported: `provider` is a dependency-injection
/// package with no opinion about async, so the loading / data / error union
/// every screen renders has to live in the app. Screens read it through
/// [when] and [valueOrNull], so a card never has to track three fields of its
/// own and get the combinations wrong.
@immutable
class AsyncState<T> {
  const AsyncState._({
    T? value,
    this.hasValue = false,
    this.error,
    this.stackTrace,
    this.isLoading = false,
  }) : _value = value;

  const AsyncState.loading() : this._(isLoading: true);

  const AsyncState.data(T value) : this._(value: value, hasValue: true);

  const AsyncState.error(Object error, [StackTrace? stackTrace])
    : this._(error: error, stackTrace: stackTrace);

  final T? _value;

  /// True once a fetch has landed. Distinct from `valueOrNull != null`, which
  /// cannot tell "loaded nothing" from "not loaded" when T is nullable.
  final bool hasValue;

  final Object? error;
  final StackTrace? stackTrace;
  final bool isLoading;

  /// The value if one has landed, otherwise null — for the places that would
  /// rather show a dash than a spinner.
  T? get valueOrNull => _value;

  /// Renders whichever of the three the value currently is.
  ///
  /// A value already loaded wins over a refetch in flight, so pulling to
  /// refresh leaves what is on screen in place instead of blanking it.
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace? stackTrace) error,
  }) {
    if (hasValue) return data(_value as T);
    if (this.error != null) return error(this.error!, stackTrace);

    return loading();
  }
}

/// A [ChangeNotifier] holding one value fetched from the server.
///
/// Subclasses say what the call is ([fetch]) and what it reads besides the
/// repository ([dependencies]); everything else — caching, refetching on a
/// changed input, superseding a slow response, never throwing out of a
/// refresh — is handled here so nineteen of these do not each get it slightly
/// wrong.
///
/// The cache is lazy on purpose. [invalidate] only marks the value stale; the
/// fetch happens when a screen next reads [state]. That keeps the blunt
/// "invalidate everything a write could move" helpers in `data_providers.dart`
/// as cheap as they were under `autoDispose`: invalidating a notifier no
/// screen is watching costs a boolean, not a request.
abstract class AsyncNotifier<T> extends ChangeNotifier {
  AsyncState<T> _state = AsyncState<T>.loading();

  SpendLogRepository? _repository;
  List<Object?>? _lastDependencies;

  bool _needsLoad = true;
  bool _disposed = false;

  /// Rises with every fetch so a slow response that has been superseded — by
  /// a newer month, a newer filter — cannot land on top of the current one.
  int _generation = 0;

  /// The repository the call goes through, bound by the provider.
  @protected
  SpendLogRepository get repository => _repository!;

  /// The value, fetching it first if it is missing or stale.
  ///
  /// Reading is what turns a stale cache into a request, which is why
  /// [invalidate] can afford to be indiscriminate.
  AsyncState<T> get state {
    if (_needsLoad && _repository != null) {
      _needsLoad = false;
      scheduleMicrotask(_load);
    }

    return _state;
  }

  /// The value without the read side effect, for a notifier's own internals.
  @protected
  AsyncState<T> get current => _state;

  /// The call itself, reading whatever this notifier depends on.
  @protected
  Future<T> fetch();

  /// What the fetch reads besides the repository — a month, a filter set.
  /// Compared on every rebind, the way `ref.watch` inside a provider re-ran
  /// the fetch when what it watched moved.
  @protected
  List<Object?> get dependencies => const [];

  /// Point at the current repository and note the current inputs. Called by
  /// the provider on every rebuild of a dependency; a new repository instance
  /// means the language changed, so anything cached was written in the old one.
  void bind(SpendLogRepository repository) {
    final repositoryChanged =
        _repository != null && !identical(_repository, repository);
    _repository = repository;

    final deps = dependencies;
    final dependenciesChanged =
        _lastDependencies != null && !listEquals(_lastDependencies, deps);
    _lastDependencies = deps;

    // Silent: this runs inside a provider's `update`, and the widget that
    // moved the input is already rebuilding — its read of [state] below is
    // what starts the new fetch.
    if (repositoryChanged || dependenciesChanged) markStale();
  }

  /// Drop the cached value without asking for a new one.
  @protected
  void markStale() => _needsLoad = true;

  /// Drop the cached value and tell watchers, so a screen showing it asks for
  /// the fresh one. Free for a notifier nothing is watching.
  void invalidate() {
    _needsLoad = true;
    _notifySoon();
  }

  /// Fetch now, whatever the cache says, and complete when it lands — what a
  /// pull-to-refresh awaits.
  ///
  /// Never throws. `RefreshIndicator` discards the future its `onRefresh`
  /// returns, so an error completing there would surface as an *unhandled*
  /// exception; the failure is already in [state], which the screen renders.
  Future<void> refresh() {
    _needsLoad = false;

    return _load();
  }

  Future<void> _load() async {
    if (_disposed || _repository == null) return;

    final generation = ++_generation;

    // Keep what is on screen while refetching. Dropping to a spinner would
    // blank the very page a pull-to-refresh is refreshing.
    if (!_state.hasValue) emit(AsyncState<T>.loading());

    try {
      final value = await fetch();
      if (generation == _generation) emit(AsyncState<T>.data(value));
    } catch (error, stackTrace) {
      if (generation == _generation) {
        emit(AsyncState<T>.error(error, stackTrace));
      }
    }
  }

  @protected
  void emit(AsyncState<T> next) {
    if (_disposed) return;

    _state = next;
    notifyListeners();
  }

  /// Notifications are deferred a microtask because [invalidate] is called
  /// from build callbacks and provider `update`s, where notifying at once
  /// would rebuild a widget in the middle of building it.
  void _notifySoon() {
    if (_disposed || !hasListeners) return;

    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// [AsyncNotifier]'s keyed twin: one value per key, in one notifier.
///
/// Stands in for Riverpod's `.family`. A single notifier rather than one per
/// key because `provider` looks providers up by type — and the screens that
/// use it show one key at a time anyway.
abstract class FamilyAsyncNotifier<T, K> extends ChangeNotifier {
  final Map<K, AsyncState<T>> _states = {};
  final Map<K, int> _generations = {};
  final Set<K> _stale = {};

  SpendLogRepository? _repository;
  bool _disposed = false;

  @protected
  SpendLogRepository get repository => _repository!;

  @protected
  Future<T> fetch(K key);

  /// The value for [key], fetching it first if it is missing or stale.
  AsyncState<T> state(K key) {
    final known = _states[key];

    if (_repository != null && (known == null || _stale.remove(key))) {
      _states[key] = known ?? AsyncState<T>.loading();
      scheduleMicrotask(() => _load(key));
    }

    return _states[key] ?? AsyncState<T>.loading();
  }

  void bind(SpendLogRepository repository) {
    final changed =
        _repository != null && !identical(_repository, repository);
    _repository = repository;

    // A new repository means a new language: every key's value was written in
    // the old one.
    if (changed) _stale.addAll(_states.keys);
  }

  /// Drops one key, or every key when none is named.
  void invalidate([K? key]) {
    if (key == null) {
      _stale.addAll(_states.keys);
    } else {
      _stale.add(key);
    }

    if (_disposed || !hasListeners) return;

    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  /// Fetch [key] now and complete when it lands. Never throws — see
  /// [AsyncNotifier.refresh].
  Future<void> refresh(K key) {
    _stale.remove(key);

    return _load(key);
  }

  Future<void> _load(K key) async {
    if (_disposed || _repository == null) return;

    final generation = (_generations[key] ?? 0) + 1;
    _generations[key] = generation;

    if (!(_states[key]?.hasValue ?? false)) {
      _emit(key, AsyncState<T>.loading());
    }

    try {
      final value = await fetch(key);
      if (_generations[key] == generation) {
        _emit(key, AsyncState<T>.data(value));
      }
    } catch (error, stackTrace) {
      if (_generations[key] == generation) {
        _emit(key, AsyncState<T>.error(error, stackTrace));
      }
    }
  }

  void _emit(K key, AsyncState<T> next) {
    if (_disposed) return;

    _states[key] = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// One piece of screen state — a month, a filter set — that the data
/// notifiers read.
///
/// Subclassed per value rather than used bare: `provider` resolves by type, so
/// four `ValueState<String>`s in one tree would all be the same provider.
abstract class ValueState<T> extends ChangeNotifier {
  ValueState(this._value);

  T _value;

  T get value => _value;

  set value(T next) {
    if (next == _value) return;

    _value = next;
    notifyListeners();
  }

  /// Rewrites the value from the current one, for the fields that are edited
  /// a piece at a time.
  void update(T Function(T current) change) => value = change(_value);
}
