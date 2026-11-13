import 'dart:async';

import 'package:flutter/foundation.dart';

/// Base class for the ViewModels (MVVM).
///
/// - Model: `models/` (data) and `services/` (Firebase, GPS, ML Kit).
/// - ViewModel: holds a screen's data and actions, talks to the services.
/// - View: `screens/` and `widgets/` only draw the ViewModel and call it.
///
/// [follow] keeps a value up to date from a live Firestore stream, so the
/// View redraws by itself when the data changes. [run] runs an action
/// (save, place order...) with [busy] on while it works; errors are passed
/// on so the View can show a message in the user's language.
abstract class ViewModel extends ChangeNotifier {
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false;

  /// An action is running: Views show a spinner and disable the button.
  bool busy = false;

  /// The last error from a live stream; null while everything is fine.
  Object? error;

  @protected
  void follow<T>(Stream<T> stream, void Function(T value) onData) {
    _subscriptions.add(
      stream.listen(
        (value) {
          onData(value);
          error = null;
          notify();
        },
        onError: (Object e) {
          error = e;
          notify();
        },
      ),
    );
  }

  @protected
  Future<T> run<T>(Future<T> Function() action) async {
    busy = true;
    notify();
    try {
      return await action();
    } finally {
      busy = false;
      notify();
    }
  }

  /// True after the page closed (stop work that finished late).
  @protected
  bool get disposed => _disposed;

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
