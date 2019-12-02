// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/memory.dart';
import 'package:reporting/reporting.dart';
//import 'package:tool_base/runner.dart' as runner;
import 'package:sylph/runner.dart' as runner;
import 'package:sylph/src/base/runner/sylph_command.dart';
import 'package:sylph/src/base/version.dart';
import 'package:test/test.dart';
import 'package:tool_base/src/base/file_system.dart';
import 'package:tool_base/src/base/io.dart' as io;
import 'package:tool_base/src/base/common.dart';
import 'package:tool_base/src/cache.dart';
import 'package:tool_base/tool_base.dart';
//import 'package:tool_base/src/reporting/reporting.dart';
//import 'package:tool_base/src/runner/flutter_command.dart';
import 'package:tool_base_test/tool_base_test.dart';
import 'package:platform/platform.dart';

import '../../src/mocks.dart';

//import '../../src/common.dart';
//import '../../src/context.dart';

void main() {
  group('runner', () {
    setUp(() {
      runner.crashFileSystem = MemoryFileSystem();
      // Instead of exiting with dart:io exit(), this causes an exception to
      // be thrown, which we catch with the onError callback in the zone below.
      io.setExitFunctionForTests((int _) { throw 'test exit';});
      Cache.disableLocking();
    });

    tearDown(() {
      runner.crashFileSystem = const LocalFileSystem();
      io.restoreExitFunction();
      Cache.enableLocking();
    });

    testUsingContext('error handling', () async {
      final Completer<void> completer = Completer<void>();
      // runner.run() asynchronously calls the exit function set above, so we
      // catch it in a zone.
      unawaited(runZoned<Future<void>>(() {
        unawaited(runner.run(
          <String>['test'],
          <SylphCommand>[
            CrashingSylphCommand(),
          ],
          // This flutterVersion disables crash reporting.
          sylphVersion: '[user-branch]/',
          reportCrashes: true,
        ));
        return null;
      },
          onError: (Object error) {
            expect(error, 'test exit');
            completer.complete();
          }));
      await completer.future;

      // This is the main check of this test.
      //
      // We are checking that, even though crash reporting failed with an
      // exception on the first attempt, the second attempt tries to report the
      // *original* crash, and not the crash from the first crash report
      // attempt.
      final CrashingUsage crashingUsage = sylphUsage;
      expect(crashingUsage.sentException, 'runCommand');
    }, overrides: <Type, Generator>{
      Platform: () => FakePlatform(environment: <String, String>{
        'FLUTTER_ANALYTICS_LOG_FILE': 'test',
        'FLUTTER_ROOT': '/',
        'HOME': '/',
      }),
      FileSystem: () => MemoryFileSystem(),
      Usage: () => CrashingUsage(),
      FlutterVersion: () => MockFlutterVersion(),
//      Logger: () => BufferLogger(),
    });
  });
}

class CrashingSylphCommand extends SylphCommand {
  @override
  String get description => null;

  @override
  String get name => 'test';

  @override
  Future<SylphCommandResult> runCommand() async {
    throw 'runCommand';
  }
}

class CrashingUsage implements Usage {
  CrashingUsage() : _impl = Usage('', '', versionOverride: '[user-branch]');

  final Usage _impl;

  dynamic get sentException => _sentException;
  dynamic _sentException;

  bool _firstAttempt = true;

  // Crash while crashing.
  @override
  void sendException(dynamic exception) {
    if (_firstAttempt) {
      _firstAttempt = false;
      throw 'sendException';
    }
    _sentException = exception;
  }

  @override
  bool get isFirstRun => _impl.isFirstRun;

  @override
  bool get suppressAnalytics => _impl.suppressAnalytics;

  @override
  set suppressAnalytics(bool value) {
    _impl.suppressAnalytics = value;
  }

  @override
  bool get enabled => _impl.enabled;

  @override
  set enabled(bool value) {
    _impl.enabled = value;
  }

  @override
  String get clientId => _impl.clientId;

  @override
  void sendCommand(String command, {Map<String, String> parameters}) =>
      _impl.sendCommand(command, parameters: parameters);

  @override
  void sendEvent(String category, String parameter, {
    Map<String, String> parameters
  }) => _impl.sendEvent(category, parameter, parameters: parameters);

  @override
  void sendTiming(String category, String variableName, Duration duration, {
    String label
  }) => _impl.sendTiming(category, variableName, duration, label: label);

  @override
  Stream<Map<String, dynamic>> get onSend => _impl.onSend;

  @override
  Future<void> ensureAnalyticsSent() => _impl.ensureAnalyticsSent();

  @override
  void printWelcome() => _impl.printWelcome();
}
