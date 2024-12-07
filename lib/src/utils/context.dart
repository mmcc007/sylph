import 'dart:async';

/// A context that can be used to store and retrieve values.
class Context {
  static final Context _instance = Context._();
  static Context get instance => _instance;

  Context._();

  final Map<Type, dynamic> _values = {};

  /// Set a value in the context.
  void set<T>(T value) {
    _values[T] = value;
  }

  /// Get a value from the context.
  T get<T>() {
    final value = _values[T];
    if (value == null) {
      throw StateError('No value of type $T found in context');
    }
    return value as T;
  }

  /// Run a function with a set of values in the context.
  Future<T> run<T>({
    required Map<Type, dynamic> overrides,
    required Future<T> Function() body,
  }) async {
    final oldValues = Map<Type, dynamic>.from(_values);
    _values.addAll(overrides);
    try {
      return await body();
    } finally {
      _values.clear();
      _values.addAll(oldValues);
    }
  }

  /// Clear all values from the context.
  void clear() {
    _values.clear();
  }
}
