// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:reporting/reporting.dart';
//import 'package:sylph/runner.dart';
import 'package:sylph/src/base/user_messages.dart';
import 'package:sylph/src/base/version.dart';
import 'package:sylph/src/commands/config.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import '../src/common_tools.dart';
import '../src/mocks.dart';
//import '../src/context.dart';

void main() {
  Testbed testbed;
  NoOpUsage noOpUsage;
  MockClock clock;
  List<int> mockTimes;

  setUpAll(() {
    Cache.disableLocking();
  });

  setUp(() {
    testbed = Testbed(
      setup: () async {
        noOpUsage=NoOpUsage();
        clock = MockClock();
        when(clock.now()).thenAnswer((Invocation _) =>
            DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
        mockTimes = <int>[1000, 2000];
      }, overrides: <Type, Generator>{
        FlutterVersion: () => MockFlutterVersion(),
        Usage: () => noOpUsage,
        UserMessages: () => UserMessages(),
        Cache: () => Cache(),
      FileSystem: () => MemoryFileSystem(),
    },);
  });

  group('config', () {
    testUsingContext('enables analytics', () => testbed.run(() async {
      final ConfigCommand configCommand = ConfigCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(configCommand);

      await commandRunner.run(<String>[configCommand.name, '--analytics']);
      expect(testLogger.statusText, contains('Analytics reporting enabled.\n'));
      expect(config.getValue('enabled'), isTrue);
    }));

    testUsingContext('disables analytics', () => testbed.run(() async {
      final ConfigCommand configCommand = ConfigCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(configCommand);

      await commandRunner.run(<String>[configCommand.name, '--no-analytics']);
      expect(
          testLogger.statusText, contains('Analytics reporting disabled.\n'));
      expect(config.getValue('enabled'), isFalse);
    }));

    testUsingContext("outputs contents", () => testbed.run(() async {
      final ConfigCommand configCommand = ConfigCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(configCommand);

      await commandRunner.run(<String>[
        configCommand.name,
      ]);
      expect(testLogger.statusText,
//          contains('Analytics reporting is currently enabled.\n'));
      contains('Analytics reporting is currently disabled.\n'));

      mockTimes = <int>[1000, 2000];
      await commandRunner.run(<String>[configCommand.name, '--no-analytics']);
      expect(testLogger.statusText,
          contains('Analytics reporting disabled.\n')); // hack for now
    }), overrides: <Type, Generator>{
      Platform: () => FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{
          'CI': 'true',
          'HOME': '/',
        },
//        script: Uri(scheme: 'data'),
      ),
    });
  });
}
