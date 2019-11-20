// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:reporting/reporting.dart';
import 'package:sylph/runner.dart';
import 'package:sylph/src/commands/config.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import '../src/common_tools.dart';
import '../src/mocks.dart';
//import '../src/context.dart';

void main() {
//  MockAndroidStudio mockAndroidStudio;
//  MockAndroidSdk mockAndroidSdk;
//  MockFlutterVersion mockFlutterVersion;
  MockClock clock;
  List<int> mockTimes;
//  Directory tempDir;

  setUpAll(() {
//    Cache.disableLocking();
  });

  setUp(() {
//    mockAndroidStudio = MockAndroidStudio();
//    mockAndroidSdk = MockAndroidSdk();
//    mockFlutterVersion = MockFlutterVersion();
    clock = MockClock();
    when(clock.now()).thenAnswer((Invocation _) =>
        DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
    mockTimes = <int>[1000, 2000];
//    tempDir = fs.systemTempDirectory.createTempSync('config_test');
  });

  group('config', () {
    testUsingContext('enables analytics', () async {
      final ConfigCommand configCommand = ConfigCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(configCommand);

      await commandRunner.run(<String>[configCommand.name, '--analytics']);
      expect(testLogger.statusText, contains('Analytics reporting enabled.\n'));
      expect(config.getValue('enabled'), isTrue);
    }, overrides: <Type, Generator>{
      FileSystem: () => MemoryFileSystem(),
//      Platform: () => platform,
      SystemClock: () => clock,
      Usage: () => FakeUsage(),
    });

    testUsingContext('disables analytics', () async {
      final ConfigCommand configCommand = ConfigCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(configCommand);

      await commandRunner.run(<String>[configCommand.name, '--no-analytics']);
      expect(
          testLogger.statusText, contains('Analytics reporting disabled.\n'));

//      final configPath = '${platform.environment['HOME']}/.$kSettings';
//      print(platform.environment['HOME']);
//      final configPath = '${platform.environment['HOME']}/.$kSettings';
//      final configFile = fs.file(configPath);
//      expect(configFile.existsSync(), isTrue);
//      final config = Config(configFile);
//      print(config.configPath);
      expect(config.getValue('enabled'), isFalse);
    }, overrides: <Type, Generator>{
      FileSystem: () => MemoryFileSystem(),
//      Platform: () => platform,
      SystemClock: () => clock,
//      Usage: () => Usage(kAnalyticsUA, kSettings),
      Usage: () => FakeUsage(),
//    Platform: ()=>FakePlatform(environment:{'HOME':platform.environment['HOME']} ),
//    Platform:()=>FakePlatform.fromPlatform(const LocalPlatform())..environment={'HOME':platform.environment['HOME']},
//      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
//        ..operatingSystem = 'macos'
//        ..environment['HOME']= tempDir.path,
    });

    testUsingContext("outputs contents", () async {
      final ConfigCommand configCommand = ConfigCommand();
      final CommandRunner<void> commandRunner =
      createTestCommandRunner(configCommand);

      await commandRunner.run(<String>[configCommand.name,]);
      expect(
          testLogger.statusText, contains('Analytics reporting is currently disabled.\n'));

      mockTimes = <int>[1000, 2000];   await commandRunner.run(<String>[configCommand.name, '--analytics']);
      expect(
          testLogger.statusText, contains('Analytics reporting is currently enabled.\n'));

    }, overrides: <Type, Generator>{
      SystemClock: () => clock,
      Usage: () => Usage(kAnalyticsUA, kSettings),
    });
//    testUsingContext('machine flag', () async {
//      final BufferLogger logger = context.get<Logger>();
//      final ConfigCommand command = ConfigCommand();
//      await command.handleMachine();
//
//      expect(logger.statusText, isNotEmpty);
//      final dynamic jsonObject = json.decode(logger.statusText);
//      expect(jsonObject, isMap);
//      print('jsonObject=$jsonObject');

//      expect(jsonObject.containsKey('android-studio-dir'), true);
//      expect(jsonObject['android-studio-dir'], isNotNull);
//
//      expect(jsonObject.containsKey('android-sdk'), true);
//      expect(jsonObject['android-sdk'], isNotNull);
//    }, overrides: <Type, Generator>{
//      AndroidStudio: () => mockAndroidStudio,
//      AndroidSdk: () => mockAndroidSdk,
//    Usage :()=>FakeUsage(),
//    });

//    testUsingContext('Can set build-dir', () async {
//      final ConfigCommand configCommand = ConfigCommand();
//      final CommandRunner<void> commandRunner = createTestCommandRunner(configCommand);
//
//      await commandRunner.run(<String>[
//        'config',
//        '--build-dir=foo'
//      ]);
//
//      expect(getBuildDirectory(), 'foo');
//    });
//
//    testUsingContext('throws error on absolute path to build-dir', () async {
//      final ConfigCommand configCommand = ConfigCommand();
//      final CommandRunner<void> commandRunner = createTestCommandRunner(configCommand);
//
//      expect(() => commandRunner.run(<String>[
//        'config',
//        '--build-dir=/foo'
//      ]), throwsA(isInstanceOf<ToolExit>()));
//    });
//
//    testUsingContext('allows setting and removing feature flags', () async {
//      final ConfigCommand configCommand = ConfigCommand();
//      final CommandRunner<void> commandRunner = createTestCommandRunner(configCommand);
//
//      await commandRunner.run(<String>[
//        'config',
//        '--enable-web',
//        '--enable-linux-desktop',
//        '--enable-windows-desktop',
//        '--enable-macos-desktop'
//      ]);
//
//      expect(Config.instance.getValue('enable-web'), true);
//      expect(Config.instance.getValue('enable-linux-desktop'), true);
//      expect(Config.instance.getValue('enable-windows-desktop'), true);
//      expect(Config.instance.getValue('enable-macos-desktop'), true);
//
//      await commandRunner.run(<String>[
//        'config', '--clear-features',
//      ]);
//
//      expect(Config.instance.getValue('enable-web'), null);
//      expect(Config.instance.getValue('enable-linux-desktop'), null);
//      expect(Config.instance.getValue('enable-windows-desktop'), null);
//      expect(Config.instance.getValue('enable-macos-desktop'), null);
//
//      await commandRunner.run(<String>[
//        'config',
//        '--no-enable-web',
//        '--no-enable-linux-desktop',
//        '--no-enable-windows-desktop',
//        '--no-enable-macos-desktop'
//      ]);
//
//      expect(Config.instance.getValue('enable-web'), false);
//      expect(Config.instance.getValue('enable-linux-desktop'), false);
//      expect(Config.instance.getValue('enable-windows-desktop'), false);
//      expect(Config.instance.getValue('enable-macos-desktop'), false);
//    }, overrides: <Type, Generator>{
////      AndroidStudio: () => mockAndroidStudio,
////      AndroidSdk: () => mockAndroidSdk,
//    });
//
//    testUsingContext('displays which config settings are available on stable', () async {
//      final BufferLogger logger = context.get<Logger>();
//      when(mockFlutterVersion.channel).thenReturn('stable');
//      final ConfigCommand configCommand = ConfigCommand();
//      final CommandRunner<void> commandRunner = createTestCommandRunner(configCommand);
//
//      await commandRunner.run(<String>[
//        'config',
//        '--enable-web',
//        '--enable-linux-desktop',
//        '--enable-windows-desktop',
//        '--enable-macos-desktop'
//      ]);
//
//      await commandRunner.run(<String>[
//        'config',
//      ]);
//
//      expect(logger.statusText, contains('enable-web: true (Unavailable)'));
//      expect(logger.statusText, contains('enable-linux-desktop: true (Unavailable)'));
//      expect(logger.statusText, contains('enable-windows-desktop: true (Unavailable)'));
//      expect(logger.statusText, contains('enable-macos-desktop: true (Unavailable)'));
//    }, overrides: <Type, Generator>{
////      AndroidStudio: () => mockAndroidStudio,
////      AndroidSdk: () => mockAndroidSdk,
////      FlutterVersion: () => mockFlutterVersion,
//    });
  });
}

//class MockAndroidStudio extends Mock implements AndroidStudio, Comparable<AndroidStudio> {
//  @override
//  String get directory => 'path/to/android/stdio';
//}
//
//class MockAndroidSdk extends Mock implements AndroidSdk {
//  @override
//  String get directory => 'path/to/android/sdk';
//}
//
//class MockFlutterVersion extends Mock implements FlutterVersion {}
