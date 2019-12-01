import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:reporting/reporting.dart';
import 'package:sylph/src/base/user_messages.dart';
import 'package:sylph/src/base/version.dart';
import 'package:sylph/src/bundle.dart';
import 'package:sylph/src/commands/run.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/sylph.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart' hide Config;
import 'package:tool_base_test/tool_base_test.dart';
import 'package:version/version.dart' as v;

import '../src/common_tools.dart';
import '../src/mocks.dart';

const String _kProjectRoot = '/project';
const String _kTempDir = '/tmp/sylph';

main() {
  group('run', () {
    Testbed testbed;
    NoOpUsage noOpUsage;
    MockClock clock;
    List<int> mockTimes;
    MemoryFileSystem fs;
    MockDeviceFarm mockDeviceFarm;
    MockProcessManager mockProcessManager;
    MockBundle mockBundle;
    MockProcess mockProcess;


    setUpAll(() {
      Cache.disableLocking();
    });

    setUp(() {
      testbed = Testbed(
          setup: () async {
            noOpUsage = NoOpUsage();
            fs = MemoryFileSystem();
            fs.directory(_kProjectRoot).createSync(recursive: true);
            fs.directory(_kTempDir).createSync(recursive: true);
            fs.currentDirectory = _kProjectRoot;
            mockDeviceFarm = MockDeviceFarm();
            mockProcessManager = MockProcessManager();
            mockBundle = MockBundle();
            mockProcess = MockProcess();
            clock = MockClock();
            when(clock.now()).thenAnswer((Invocation _) =>
                DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
            mockTimes = <int>[1000, 2000, 3000, 4000, 5000, 6000];
          }, overrides: <Type, Generator>{
        FlutterVersion: () => MockFlutterVersion(),
        Usage: () => noOpUsage,
        UserMessages: () => UserMessages(),
        Cache: () => Cache(),
//        FileSystem: () => MemoryFileSystem(),
//        Logger: () => BufferLogger(),
      });
      noOpUsage = NoOpUsage();
      fs = MemoryFileSystem();
      fs.directory(_kProjectRoot).createSync(recursive: true);
      fs.directory(_kTempDir).createSync(recursive: true);
      fs.currentDirectory = _kProjectRoot;
      mockDeviceFarm = MockDeviceFarm();
      mockProcessManager = MockProcessManager();
      mockBundle = MockBundle();
      mockProcess = MockProcess();
      clock = MockClock();
      when(clock.now()).thenAnswer((Invocation _) =>
          DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0)));
      mockTimes = <int>[1000, 2000, 3000, 4000, 5000, 6000];
    });

//    testUsingContext('normal run', () => testbed.run(() async {
      testUsingContext('normal run', () async {
      final configFile = fs.file('$_kProjectRoot/sylph.yaml');
      configFile.createSync();
      configFile.writeAsStringSync(configStr);
      final config = Config(configPath: configFile.path);
      fs.file(config.testSuites[0].main).createSync(recursive: true);
      fs.file(config.testSuites[0].tests[0]).createSync();
      final pubspec = fs.file('pubspec.yaml');
      pubspec.createSync();
      pubspec.writeAsStringSync('name: test_app');

      when(mockBundle.bundleFlutterTests(any)).thenReturn('size in MB');
      when(mockProcessManager.runSync(
        any,
        environment: anyNamed('environment'),
        workingDirectory: anyNamed('workingDirectory'),
      )).thenReturn(exitsHappy);

      when(mockProcessManager.start(
        any,
        environment: anyNamed('environment'),
        workingDirectory: anyNamed('workingDirectory'),
      )).thenAnswer((_) async => mockProcess);

      when(mockDeviceFarm.getDeviceFarmDevices()).thenReturn([
        DeviceFarmDevice(
          'Samsung Galaxy Note 4 SM-N910H',
          'SM-N910H',
          v.Version(5, 0, 1),
          DeviceType.android,
          FormFactor.phone,
          'AVAILABLE',
          'arn1',
        ),
        DeviceFarmDevice(
          'Apple iPhone 6 Plus',
          'A1522',
          v.Version(10, 0, 2),
          DeviceType.ios,
          FormFactor.phone,
          'AVAILABLE',
          'arn2',
        )
      ]);
      when(mockDeviceFarm.runReport(any)).thenReturn(true);

      final RunCommand runCommand = RunCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(runCommand);
      await commandRunner.run(<String>[runCommand.name]);
      expect(testLogger.statusText, contains(' succeeded.\n'));
      print(testLogger.statusText);

      verify(mockBundle.bundleFlutterTests(any)).called(1);
      verify(mockProcessManager.runSync(
        any,
        environment: anyNamed('environment'),
        workingDirectory: anyNamed('workingDirectory'),
      )).called(3);
      verify(mockProcessManager.start(
        any,
        environment: anyNamed('environment'),
        workingDirectory: anyNamed('workingDirectory'),
      )).called(1);
      verify(mockDeviceFarm.getDeviceFarmDevices()).called(1);
      verify(mockDeviceFarm.runReport(any)).called(1);
    }, overrides: <Type, Generator>{
      FileSystem: () => fs,
      SystemClock: () => clock,
      DeviceFarm: () => mockDeviceFarm,
      ProcessManager: () => mockProcessManager,
      Bundle: () => mockBundle,
        FlutterVersion: () => MockFlutterVersion(),
        Usage: () => noOpUsage,
        UserMessages: () => UserMessages(),
      });

    testUsingContext('help', () => testbed.run(() async {
      final RunCommand runCommand = RunCommand();
      final CommandRunner<void> commandRunner =
          createTestCommandRunner(runCommand);
      await commandRunner.run(<String>['help', runCommand.name]);
      expect(testLogger.statusText, isEmpty);
    }));
  });
}

class MockProcessManager extends Mock implements ProcessManager {}

class MockBundle extends Mock implements Bundle {}

class MockDeviceFarm extends Mock implements DeviceFarm {}

final ProcessResult exitsHappy = ProcessResult(
  1, // pid
  0, // exitCode
  '', // stdout
  '', // stderr
);

final configStr = '''
        tmp_dir: /tmp/sylph
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
        concurrent_runs: false
        flavor: dev
        android_package_name: com.app.package
        android_app_id: com.id.dev
        project_name: Test App
        default_job_timeout: 15 
        device_pools:
          - pool_name: android pool 1
            pool_type: android
            devices:
              - name: Samsung Galaxy Note 4 SM-N910H
                model: SM-N910H
                os: 5.0.1
          - pool_name: ios pool 1
            pool_type: ios
            devices:
              - name: Apple iPhone 6 Plus
                model: A1522
                os: 10.0.2
        test_suites:
          - test_suite: example tests 1
            main: test_driver/main.dart
            tests:
              - test_driver/main_test.dart
            pool_names:
              - android pool 1
#              - ios pool 1
            job_timeout: 15
      ''';
