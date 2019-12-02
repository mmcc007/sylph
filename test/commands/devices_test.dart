/*
 * Copyright 2019 The Sylph Authors. All rights reserved.
 *  Sylph runs Flutter integration tests on real devices in the cloud.
 *  Use of this source code is governed by a GPL-style license that can be
 *  found in the LICENSE file.
 */

import 'package:args/command_runner.dart';
import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:reporting/reporting.dart';
import 'package:sylph/src/base/user_messages.dart';
import 'package:sylph/src/base/version.dart';
import 'package:sylph/src/commands/devices.dart';
import 'package:sylph/src/device_farm.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import '../src/common_tools.dart';
import '../src/mocks.dart';

main() {
  group('devices', () {
    Testbed testbed;
    NoOpUsage noOpUsage;
    MockClock clock;
    List<int> mockTimes;
    FakeProcessManager fakeProcessManager;

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
          fakeProcessManager = FakeProcessManager();
        }, overrides: <Type, Generator>{
        FlutterVersion: () => MockFlutterVersion(),
        Usage: () => noOpUsage,
        UserMessages: () => UserMessages(),
        Cache: () => Cache(),
        FileSystem: () => MemoryFileSystem(),
        Logger: () => BufferLogger(),
        SystemClock: () => clock,
        ProcessManager: () => fakeProcessManager,
        DeviceFarm:()=>DeviceFarm(),
      },);

    });

    final calls = [
      Call(
          'aws devicefarm list-devices',
          ProcessResult(
              0,
              0,
              jsonEncode(
                {
                  "devices": [
                    {
                      "arn":
                          "arn:aws:devicefarm:us-west-2::device:70D5B22608A149568923E4A225EC5E04",
                      "name": "Samsung Galaxy Note 4 SM-N910H",
                      "manufacturer": "Samsung",
                      "model": "Galaxy Note 4 SM-N910H",
                      "modelId": "SM-N910H",
                      "formFactor": "PHONE",
                      "platform": "ANDROID",
                      "os": "5.0.1",
                      "fleetType": "PUBLIC",
                      "availability": "AVAILABLE"
                    },
                    {
                      "arn":
                          "arn:aws:devicefarm:us-west-2::device:352FDCFAA36C43AC8228DC8F23355272",
                      "name": "Apple iPhone 6 Plus",
                      "manufacturer": "Apple",
                      "model": "iPhone 6 Plus",
                      "modelId": "A1522",
                      "formFactor": "PHONE",
                      "platform": "IOS",
                      "os": "10.0.2",
                      "fleetType": "PUBLIC",
                      "availability": "HIGHLY_AVAILABLE"
                    }
                  ]
                },
              ),
              '')),
    ];

    testUsingContext('lists all devices in cloud', () => testbed.run(() async {
      fakeProcessManager.calls = calls;
      final DevicesCommand devicesCommand = DevicesCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(devicesCommand);
      await commandRunner.run(<String>[devicesCommand.name]);
      fakeProcessManager.verifyCalls();
      expect(testLogger.statusText, contains('2 devices\n'));
    }));

    testUsingContext('lists android devices in cloud', () => testbed.run(() async {
      fakeProcessManager.calls = calls;
      final DevicesCommand devicesCommand = DevicesCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(devicesCommand);
      await commandRunner.run(<String>[devicesCommand.name, 'android']);
      fakeProcessManager.verifyCalls();
      expect(testLogger.statusText, contains('deviceType:android'));
      expect(testLogger.statusText, isNot(contains('deviceType:ios')));
    }));

    testUsingContext('lists ios devices in cloud', () => testbed.run(() async {
      fakeProcessManager.calls = calls;
      final DevicesCommand devicesCommand = DevicesCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(devicesCommand);
      await commandRunner.run(<String>[devicesCommand.name, '-d', 'ios']);
      fakeProcessManager.verifyCalls();
      expect(testLogger.statusText, contains('deviceType:ios'));
      expect(testLogger.statusText, isNot(contains('deviceType:android')));
    }));

    testUsingContext('lists ios devices in cloud using option', () => testbed.run(() async {
      fakeProcessManager.calls = calls;
      final DevicesCommand devicesCommand = DevicesCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(devicesCommand);
      await commandRunner.run(<String>[devicesCommand.name, '-d' 'ios']);
      fakeProcessManager.verifyCalls();
      expect(testLogger.statusText, contains('deviceType:ios'));
      expect(testLogger.statusText, isNot(contains('deviceType:android')));
    }));

    testUsingContext('catches bad param', () => testbed.run(() async {
      final DevicesCommand devicesCommand = DevicesCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(devicesCommand);
      expect(
          () async =>
              await commandRunner.run(<String>[devicesCommand.name, 'xxx']),
          throwsA(isA<ToolExit>()));
    }));

    testUsingContext('shows help', () => testbed.run(() async {
      final DevicesCommand devicesCommand = DevicesCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(devicesCommand);
      await commandRunner.run(<String>['help', devicesCommand.name]);
      expect(
          testLogger.statusText, isEmpty);
    }));
  });
}
