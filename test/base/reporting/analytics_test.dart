// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
//import 'package:flutter_tools/src/base/config.dart';
//import 'package:flutter_tools/src/base/file_system.dart';
//import 'package:flutter_tools/src/base/io.dart';
//import 'package:flutter_tools/src/base/platform.dart';
//import 'package:flutter_tools/src/base/time.dart';
//import 'package:flutter_tools/src/cache.dart';
//import 'package:flutter_tools/src/commands/build.dart';
//import 'package:flutter_tools/src/commands/config.dart';
//import 'package:flutter_tools/src/commands/doctor.dart';
//import 'package:flutter_tools/src/doctor.dart';
//import 'package:flutter_tools/src/features.dart';
//import 'package:flutter_tools/src/reporting/reporting.dart';
//import 'package:flutter_tools/src/runner/flutter_command.dart';
//import 'package:flutter_tools/src/version.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:sylph/src/base/reporting/reporting.dart';
import 'package:sylph/src/base/runner/sylph_command.dart';
import 'package:sylph/src/base/runner/sylph_command_runner.dart';
import 'package:sylph/src/base/user_messages.dart';
import 'package:sylph/src/commands/devices.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import '../../src/mocks.dart';

//import '../src/common.dart';
//import '../src/context.dart';
//import '../src/mocks.dart';

void main() {
  group('analytics', () {
    Directory tempDir;
    MockFlutterConfig mockFlutterConfig;
    SystemClock mockClock;
    List<int> mockTimes;

    setUpAll(() {
//      Cache.disableLocking();
    });

    setUp(() {
//      Cache.flutterRoot = '../..';
      tempDir = fs.systemTempDirectory
          .createTempSync('flutter_tools_analytics_test.');
      mockFlutterConfig = MockFlutterConfig();
      mockClock = MockClock();
      when(mockClock.now()).thenAnswer((Invocation _) =>
          DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
    });

    tearDown(() {
      tryToDelete(tempDir);
    });

    // Ensure we don't send anything when analytics is disabled.
    testUsingContext('doesn\'t send when disabled', () async {
      mockTimes = <int>[1000, 2000, 3000, 4000, 5000, 6000];
      int count = 0;
      flutterUsage.onSend.listen((Map<String, dynamic> data) => count++);

      flutterUsage.enabled = false;
      await createProject(tempDir);
      expect(count, 0);

      flutterUsage.enabled = true;
      await createProject(tempDir);
      expect(count, flutterUsage.isFirstRun ? 0 : 1);

      count = 0;
      flutterUsage.enabled = false;
      final DevicesCommand doctorCommand = DevicesCommand();
      final CommandRunner<void> runner = createTestCommandRunner(doctorCommand);
      await runner.run(<String>['devices', 'ios']);
      expect(count, 0);
    }, overrides: <Type, Generator>{
//      FlutterVersion: () => FlutterVersion(const SystemClock()),
      Usage: () => Usage(
          configDirOverride: tempDir.path,
          logFile: tempDir.childFile('analytics.log').path),
      SystemClock: () => mockClock,
      UserMessages: () => UserMessages(),
    });
//
//    // Ensure we don't send for the 'flutter config' command.
//    testUsingContext('config doesn\'t send', () async {
//      int count = 0;
//      flutterUsage.onSend.listen((Map<String, dynamic> data) => count++);
//
//      flutterUsage.enabled = false;
//      final ConfigCommand command = ConfigCommand();
//      final CommandRunner<void> runner = createTestCommandRunner(command);
//      await runner.run(<String>['config']);
//      expect(count, 0);
//
//      flutterUsage.enabled = true;
//      await runner.run(<String>['config']);
//      expect(count, 0);
//    }, overrides: <Type, Generator>{
//      FlutterVersion: () => FlutterVersion(const SystemClock()),
//      Usage: () => Usage(
//          configDirOverride: tempDir.path,
//          logFile: tempDir.childFile('analytics.log').path
//      ),
//    });
//
    testUsingContext('Usage records one feature in experiment setting',
        () async {
      mockTimes = <int>[1000, 2000, 3000, 4000, 5000, 6000];

//      when<bool>(mockFlutterConfig.getValue(flutterWebFeature.configSetting))
//          .thenReturn(true);
      final Usage usage = Usage();
      usage.sendCommand('test');

      final String featuresKey = cdKey(CustomDimensions.sessionHostOsDetails);
      expect(fs.file('test').readAsStringSync(),
          contains('$featuresKey: fake OS name and version'));
    }, overrides: <Type, Generator>{
//      FlutterVersion: () => FlutterVersion(const SystemClock()),
      Config: () => mockFlutterConfig,
      Platform: () => FakePlatform(environment: <String, String>{
            'FLUTTER_ANALYTICS_LOG_FILE': 'test',
          }),
      FileSystem: () => MemoryFileSystem(),
      SystemClock: () => mockClock,
    });

    testUsingContext('Usage records multiple features in experiment setting',
        () async {
      mockTimes = <int>[1000, 2000, 3000, 4000, 5000, 6000];

//      when<bool>(mockFlutterConfig.getValue(flutterWebFeature.configSetting))
//          .thenReturn(true);
//      when<bool>(mockFlutterConfig.getValue(flutterLinuxDesktopFeature.configSetting))
//          .thenReturn(true);
//      when<bool>(mockFlutterConfig.getValue(flutterMacOSDesktopFeature.configSetting))
//          .thenReturn(true);
      final Usage usage = Usage();
      usage.sendCommand('test');

      final String featuresKey = cdKey(CustomDimensions.sessionHostOsDetails);
      expect(fs.file('test').readAsStringSync(),
          contains('$featuresKey: fake OS name and version'));
    }, overrides: <Type, Generator>{
//      FlutterVersion: () => FlutterVersion(const SystemClock()),
      Config: () => mockFlutterConfig,
      Platform: () => FakePlatform(environment: <String, String>{
            'FLUTTER_ANALYTICS_LOG_FILE': 'test',
          }),
      FileSystem: () => MemoryFileSystem(),
      SystemClock: () => mockClock,
    });
  });

  group('analytics with mocks', () {
    MemoryFileSystem memoryFileSystem;
    MockStdio mockStdio;
    Usage mockUsage;
    SystemClock mockClock;
//    Doctor mockDoctor;
    List<int> mockTimes;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      mockStdio = MockStdio();
      mockUsage = MockUsage();
      when(mockUsage.isFirstRun).thenReturn(false);
      mockClock = MockClock();
//      mockDoctor = MockDoctor();
      when(mockClock.now()).thenAnswer((Invocation _) =>
          DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
    });

//    testUsingContext('flutter commands send timing events', () async {
//      mockTimes = <int>[1000, 2000];
//      when(mockDoctor.diagnose(androidLicenses: false, verbose: false)).thenAnswer((_) async => true);
//      final DoctorCommand command = DoctorCommand();
//      final CommandRunner<void> runner = createTestCommandRunner(command);
//      await runner.run(<String>['doctor']);
//
//      verify(mockClock.now()).called(2);
//
//      expect(
//        verify(mockUsage.sendTiming(captureAny, captureAny, captureAny, label: captureAnyNamed('label'))).captured,
//        <dynamic>['flutter', 'doctor', const Duration(milliseconds: 1000), 'success'],
//      );
//    }, overrides: <Type, Generator>{
//      SystemClock: () => mockClock,
//      Doctor: () => mockDoctor,
//      Usage: () => mockUsage,
//    });
//
//    testUsingContext('doctor fail sends warning', () async {
//      mockTimes = <int>[1000, 2000];
//      when(mockDoctor.diagnose(androidLicenses: false, verbose: false)).thenAnswer((_) async => false);
//      final DoctorCommand command = DoctorCommand();
//      final CommandRunner<void> runner = createTestCommandRunner(command);
//      await runner.run(<String>['doctor']);
//
//      verify(mockClock.now()).called(2);
//
//      expect(
//        verify(mockUsage.sendTiming(captureAny, captureAny, captureAny, label: captureAnyNamed('label'))).captured,
//        <dynamic>['flutter', 'doctor', const Duration(milliseconds: 1000), 'warning'],
//      );
//    }, overrides: <Type, Generator>{
//      SystemClock: () => mockClock,
//      Doctor: () => mockDoctor,
//      Usage: () => mockUsage,
//    });

    testUsingContext('single command usage path', () async {
      final SylphCommand doctorCommand = DevicesCommand();
      expect(await doctorCommand.usagePath, 'devices');
    }, overrides: <Type, Generator>{
      Usage: () => mockUsage,
    });

//    testUsingContext('compound command usage path', () async {
//      final DevicesCommand buildCommand = DevicesCommand();
//      final SylphCommand buildApkCommand = buildCommand.subcommands['apk'];
//      expect(await buildApkCommand.usagePath, 'build/apk');
//    }, overrides: <Type, Generator>{
//      Usage: () => mockUsage,
//    });

    testUsingContext('command sends localtime', () async {
      const int kMillis = 1000;
      mockTimes = <int>[kMillis];
      // Since FLUTTER_ANALYTICS_LOG_FILE is set in the environment, analytics
      // will be written to a file.
      final Usage usage = Usage(versionOverride: 'test');
      usage.suppressAnalytics = false;
      usage.enabled = true;

      usage.sendCommand('test');

      final String log = fs.file('analytics.log').readAsStringSync();
      final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(kMillis);
      expect(log.contains(formatDateTime(dateTime)), isTrue);
    }, overrides: <Type, Generator>{
      FileSystem: () => memoryFileSystem,
      SystemClock: () => mockClock,
      Platform: () => FakePlatform(
            environment: <String, String>{
              'FLUTTER_ANALYTICS_LOG_FILE': 'analytics.log',
            },
          ),
      Stdio: () => mockStdio,
    });

    testUsingContext('event sends localtime', () async {
      const int kMillis = 1000;
      mockTimes = <int>[kMillis];
      // Since FLUTTER_ANALYTICS_LOG_FILE is set in the environment, analytics
      // will be written to a file.
      final Usage usage = Usage(versionOverride: 'test');
      usage.suppressAnalytics = false;
      usage.enabled = true;

      usage.sendEvent('test', 'test');

      final String log = fs.file('analytics.log').readAsStringSync();
      final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(kMillis);
      expect(log.contains(formatDateTime(dateTime)), isTrue);
    }, overrides: <Type, Generator>{
      FileSystem: () => memoryFileSystem,
      SystemClock: () => mockClock,
      Platform: () => FakePlatform(
            environment: <String, String>{
              'FLUTTER_ANALYTICS_LOG_FILE': 'analytics.log',
            },
          ),
      Stdio: () => mockStdio,
    });
  });

  group('analytics bots', () {
    Directory tempDir;

    setUp(() {
      tempDir = fs.systemTempDirectory
          .createTempSync('flutter_tools_analytics_bots_test.');
    });

    tearDown(() {
      tryToDelete(tempDir);
    });

    testUsingContext('don\'t send on bots', () async {
      int count = 0;
      flutterUsage.onSend.listen((Map<String, dynamic> data) => count++);

      await createTestCommandRunner().run(<String>['--version']);
      expect(count, 0);
    }, overrides: <Type, Generator>{
      Usage: () => Usage(
            settingsName: 'flutter_bot_test',
            versionOverride: 'dev/unknown',
            configDirOverride: tempDir.path,
          ),
    });

    testUsingContext('don\'t send on bots even when opted in', () async {
      int count = 0;
      flutterUsage.onSend.listen((Map<String, dynamic> data) => count++);
      flutterUsage.enabled = true;

      await createTestCommandRunner().run(<String>['--version']);
      expect(count, 0);
    }, overrides: <Type, Generator>{
      Usage: () => Usage(
            settingsName: 'flutter_bot_test',
            versionOverride: 'dev/unknown',
            configDirOverride: tempDir.path,
          ),
    });
  });
}

createProject(Directory tempDir) {
  flutterUsage.sendCommand('version');
}

class MockUsage extends Mock implements Usage {}

class MockFlutterConfig extends Mock implements Config {}

CommandRunner<void> createTestCommandRunner([SylphCommand command]) {
  final SylphCommandRunner runner = SylphCommandRunner();
  if (command != null) runner.addCommand(command);
  return runner;
}
