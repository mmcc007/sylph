import 'dart:async';
import 'package:meta/meta.dart';
import '../utils/context.dart';

/// Run a test with a specific set of context overrides.
@isTest
Future<T> testUsingContext<T>(
  String description,
  Future<T> Function() body, {
  Map<Type, dynamic> overrides = const <Type, dynamic>{},
}) async {
  return Context.instance.run(
    overrides: overrides,
    body: () async {
      try {
        return await body();
      } catch (error, stackTrace) {
        print('Error during test "$description":');
        print(error);
        print(stackTrace);
        rethrow;
      }
    },
  );
}
