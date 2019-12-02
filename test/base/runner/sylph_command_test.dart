/*
 * Copyright 2019 The Sylph Authors. All rights reserved.
 *  Sylph runs Flutter integration tests on real devices in the cloud.
 *  Use of this source code is governed by a GPL-style license that can be
 *  found in the LICENSE file.
 */

//import 'package:flutter_tools/src/base/common.dart';
//import 'package:flutter_tools/src/base/time.dart';
//import 'package:flutter_tools/src/cache.dart';
//import 'package:flutter_tools/src/reporting/reporting.dart';
//import 'package:flutter_tools/src/runner/flutter_command.dart';
//import 'package:flutter_tools/src/version.dart';
import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:reporting/reporting.dart';
import 'package:sylph/src/base/runner/sylph_command.dart';
import 'package:sylph/src/base/user_messages.dart';
import 'package:sylph/src/base/version.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

//import '../../src/common.dart';
//import '../../src/context.dart';
import '../../src/mocks.dart';
import '../../src/utils.dart';

void main() {
  group('Flutter Command', () {
    Testbed testbed;
//    MockitoCache cache;
    MockitoUsage usage;
    MockClock clock;
    List<int> mockTimes;

    setUp(() {
      testbed = Testbed(
        setup: () async {
          clock = MockClock();
          when(clock.now()).thenAnswer((Invocation _) =>
              DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
          mockTimes = <int>[1000, 2000];
          usage = MockitoUsage();
          when(usage.isFirstRun).thenReturn(false);
        }, overrides: <Type, Generator>{
        FlutterVersion: () => MockFlutterVersion(),
        Usage: () => usage,
        UserMessages: () => UserMessages(),
        Cache: () => Cache(),
        FileSystem: () => MemoryFileSystem(),
              SystemClock: () => clock,
      });
//      cache = MockitoCache();
    });

//    testUsingContext('honors shouldUpdateCache false', () async {
//      final DummyFlutterCommand flutterCommand = DummyFlutterCommand(shouldUpdateCache: false);
//      await flutterCommand.run();
//      verifyZeroInteractions(cache);
//    },
//    overrides: <Type, Generator>{
//      Cache: () => cache,
//    });
//
//    testUsingContext('honors shouldUpdateCache true', () async {
//      final DummyFlutterCommand flutterCommand = DummyFlutterCommand(shouldUpdateCache: true);
//      await flutterCommand.run();
//      verify(cache.updateAll(any)).called(1);
//    },
//    overrides: <Type, Generator>{
//      Cache: () => cache,
//    });

    testUsingContext('reports command that results in success', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final DummySylphCommand flutterCommand = DummySylphCommand(
        commandFunction: () async {
          return const SylphCommandResult(ExitStatus.success);
        }
      );
      await flutterCommand.run();

      verify(usage.sendCommand(captureAny, parameters: captureAnyNamed('parameters')));
      verify(usage.sendEvent(captureAny, 'success'));
    }));

    testUsingContext('reports command that results in warning', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final DummySylphCommand flutterCommand = DummySylphCommand(
        commandFunction: () async {
          return const SylphCommandResult(ExitStatus.warning);
        }
      );
      await flutterCommand.run();

      verify(usage.sendCommand(captureAny, parameters: captureAnyNamed('parameters')));
      verify(usage.sendEvent(captureAny, 'warning'));
    }));

    testUsingContext('reports command that results in failure', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final DummySylphCommand flutterCommand = DummySylphCommand(
        commandFunction: () async {
          return const SylphCommandResult(ExitStatus.fail);
        }
      );

      try {
        await flutterCommand.run();
      } on ToolExit {
        verify(usage.sendCommand(captureAny, parameters: captureAnyNamed('parameters')));
        verify(usage.sendEvent(captureAny, 'fail'));
      }
    }));

    testUsingContext('reports command that results in error', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final DummySylphCommand flutterCommand = DummySylphCommand(
        commandFunction: () async {
          throwToolExit('fail');
          return null; // unreachable
        }
      );

      try {
        await flutterCommand.run();
        fail('Mock should make this fail');
      } on ToolExit {
        verify(usage.sendCommand(captureAny, parameters: captureAnyNamed('parameters')));
        verify(usage.sendEvent(captureAny, 'fail'));
      }
    }));

    testUsingContext('report execution timing by default', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final DummySylphCommand flutterCommand = DummySylphCommand();
      await flutterCommand.run();
      verify(clock.now()).called(2);

      expect(
        verify(usage.sendTiming(
                captureAny, captureAny, captureAny,
                label: captureAnyNamed('label'))).captured,
        <dynamic>[
          'flutter',
          'dummy',
          const Duration(milliseconds: 1000),
          null
        ],
      );
    }));

    testUsingContext('no timing report without usagePath', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final DummySylphCommand flutterCommand =
          DummySylphCommand(noUsagePath: true);
      await flutterCommand.run();
      verify(clock.now()).called(2);
      verifyNever(usage.sendTiming(
                   any, any, any,
                   label: anyNamed('label')));
    }));

    testUsingContext('report additional SylphCommandResult data', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final SylphCommandResult commandResult = SylphCommandResult(
        ExitStatus.success,
        // nulls should be cleaned up.
        timingLabelParts: <String> ['blah1', 'blah2', null, 'blah3'],
        endTimeOverride: DateTime.fromMillisecondsSinceEpoch(1500),
      );

      final DummySylphCommand flutterCommand = DummySylphCommand(
        commandFunction: () async => commandResult
      );
      await flutterCommand.run();
      verify(clock.now()).called(2);
      expect(
        verify(usage.sendTiming(
                captureAny, captureAny, captureAny,
                label: captureAnyNamed('label'))).captured,
        <dynamic>[
          'flutter',
          'dummy',
          const Duration(milliseconds: 500), // SylphCommandResult's end time used instead.
          'success-blah1-blah2-blah3',
        ],
      );
    }));

    testUsingContext('report failed execution timing too', () => testbed.run(() async {
      // Crash if called a third time which is unexpected.
      mockTimes = <int>[1000, 2000];

      final DummySylphCommand flutterCommand = DummySylphCommand(
        commandFunction: () async {
          throwToolExit('fail');
          return null; // unreachable
        },
      );

      try {
        await flutterCommand.run();
        fail('Mock should make this fail');
      } on ToolExit {
        // Should have still checked time twice.
        verify(clock.now()).called(2);

        expect(
          verify(usage.sendTiming(
                  captureAny, captureAny, captureAny,
                  label: captureAnyNamed('label'))).captured,
          <dynamic>[
            'flutter',
            'dummy',
            const Duration(milliseconds: 1000),
            'fail',
          ],
        );
      }
    }));
  });
}


class FakeCommand extends SylphCommand {
  @override
  String get description => null;

  @override
  String get name => 'fake';

  @override
  Future<SylphCommandResult> runCommand() async {
    return null;
  }
}

//class MockVersion extends Mock implements FlutterVersion {}
