/*
 * Copyright (c) 2019.
 *     Sylph runs Flutter integration tests on real devices in the cloud.
 *     Copyright (C) 2019  Maurice McCabe
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:sylph/src/base/reporting/reporting.dart';
import 'package:sylph/src/context_runner.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import '../../src/mocks.dart';

main() {
  group('reporting', () {
    testUsingContext('send command', () async {});
  });
  group('analytics with mocks', () {
    MemoryFileSystem memoryFileSystem;
    MockStdio mockStdio;
    Usage mockUsage;
    SystemClock mockClock;
    List<int> mockTimes;

    setUp(() {
      memoryFileSystem = MemoryFileSystem();
      mockStdio = MockStdio();
      mockUsage = MockUsage();
      when(mockUsage.isFirstRun).thenReturn(false);
      mockClock = MockClock();
      when(mockClock.now()).thenAnswer((Invocation _) =>
          DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
    });

    testUsingContext('command sends localtime', () async {
      const int kMillis = 1000;
      mockTimes = <int>[kMillis];
      // Since FLUTTER_ANALYTICS_LOG_FILE is set in the environment, analytics
      // will be written to a file.
      final Usage usage = Usage(kAnalyticsUA, kSettings,versionOverride: 'test');
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
  });
}

class MockUsage extends Mock implements Usage {}

class MockFlutterConfig extends Mock implements Config {}
