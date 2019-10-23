import 'dart:async';
import 'dart:io';

import 'package:sylph/src/bundle.dart';
import 'package:sylph/src/base/concurrent_jobs.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/src/device_farm.dart';
import 'package:sylph/src/base/devices.dart';
import 'package:sylph/src/resources.dart';
import 'package:sylph/src/sylph_run.dart';
import 'package:sylph/src/base/utils.dart';
import 'package:sylph/src/validator.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const kTestProjectName = 'test concurrent runs';
const kTestProjectArn =
    'arn:aws:devicefarm:us-west-2:122621792560:project:908d123f-af8c-4d4b-9b86-65d3d51a0e49';
// successful run with multiple jobs
const kSuccessfulRunArn =
    'arn:aws:devicefarm:us-west-2:122621792560:run:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd';
const kFirstJobArn =
    'arn:aws:devicefarm:us-west-2:122621792560:job:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000';

void main() {
  group('initial tests', () {
    test('parse yaml', () async {
      final filePath = 'test/sylph_test.yaml';
      await parseYamlFile(filePath);
    });

    test('get first poolname and devices', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = await parseYamlFile(filePath);
//    print('config=$config');
      final poolName = config['device_pools'][1]['pool_name'];
      final devices = config['device_pools'][1]['devices'];
      expect(poolName, 'ios pool 1');
      expect(devices, [
        {'model': 'A1865', 'name': 'Apple iPhone X', 'os': 12.0},
        {'model': 'A1865', 'name': 'Apple iPhone X', 'os': 11.4}
      ]);
    });

    test('parse yaml from string', () async {
      String deviceFarmConfigStr = '''
    aws_user: user1
    aws_pass: pass1

    project: ios_test
    device_pool:
      ios:
        - Apple iPhone X
      android:

    test_suites:
      - test_suite: my tests 1
        app: ~/flutter_app
        tests:
         - lib/main.dart
        device_pool:
          ios:
          - Apple iPhone X
          android:

      - test_suite: my tests 2
        app: ~/flutter_app
        tests:
          - lib/main.dart''';
      final expected = {
        "aws_user": "user1",
        "project": "ios_test",
        "test_suites": [
          {
            "app": "~/flutter_app",
            "tests": ["lib/main.dart"],
            "device_pool": {
              "android": null,
              "ios": ["Apple iPhone X"]
            },
            "test_suite": "my tests 1"
          },
          {
            "app": "~/flutter_app",
            "tests": ["lib/main.dart"],
            "test_suite": "my tests 2"
          }
        ],
        "aws_pass": "pass1",
        "device_pool": {
          "android": null,
          "ios": ["Apple iPhone X"]
        }
      };
      final Map deviceFarmConfig = loadYaml(deviceFarmConfigStr);
      expect(deviceFarmConfig, expected);
    });

    test('setup project', () {
      final projectName = 'flutter test';
      final jobTimeoutMinutes = 5;
      final result = setupProject(projectName, jobTimeoutMinutes);
      final expected =
          'arn:aws:devicefarm:us-west-2:122621792560:project:c43f0049-7b2f-42ed-9e4b-c6c46de9de23';
      expect(result, expected);
    }, skip: isCI());

    test('find device ARN', () {
      final sylphDevice = loadSylphDevice({
        'name': 'Apple iPhone X',
        'model': 'A1865',
        'os': '12.0'
//      'os': '11.4'
      }, 'ios');

      final result = findDevicesArns([sylphDevice]);
      expect(result.length, 1);
      expect(result.first,
          'arn:aws:devicefarm:us-west-2::device:D125AEEE8614463BAE106865CAF4470E');
    });

    test('convert devices to a rule', () {
      final List<SylphDevice> devices = [
        loadSylphDevice({
          'name': 'Apple iPhone X',
          'model': 'A1865',
          'os': '12.0'
//      'os': '11.4'
        }, 'ios'),
        loadSylphDevice({
          'name': 'Google Pixel',
          'model': 'Pixel',
          'os': '7.1.2'
//      'os': '11.4'
        }, 'android')
      ];

      // convert devices to rules
      final rules = devicesToRule(devices);
      final expected =
          '[{"attribute": "ARN", "operator": "IN","value": "[\\"arn:aws:devicefarm:us-west-2::device:D125AEEE8614463BAE106865CAF4470E\\",\\"arn:aws:devicefarm:us-west-2::device:CEA80E8918814308A6275FEBC4310134\\"]"}]';
      expect(rules, expected);
    });

    test('setup device pool', () async {
//    final projectArn =
//        'arn:aws:devicefarm:us-west-2:122621792560:project:fb4de03d-c6ac-4d25-bd27-4a59214d2a8b';
      // 'test artifacts download'
      final projectArn =
          'arn:aws:devicefarm:us-west-2:122621792560:project:e1c97f71-f534-432b-9e86-3bd7529e327b';
      final poolName = 'ios pool xxx';
      final configStr = '''
        device_pools:
          - pool_name: $poolName
            pool_type: ios
            devices:
              - name: Apple iPhone X
                model: A1865
                os: 11.4      
      ''';

      final config = Config(configStr: configStr);

      final devicePool = config.getDevicePool(poolName);

      // check for existing pool
      final result = setupDevicePool(devicePool, projectArn);
      final expected =
          'arn:aws:devicefarm:us-west-2:122621792560:devicepool:e1c97f71-f534-432b-9e86-3bd7529e327b/d1a72830-e094-4280-b8b9-3b800ba76a31';
      expect(result, expected);
    });

    test('monitor successful run progress until complete', () async {
      final timeout = 100;
      final poolName = 'dummy pool name';
      final result = await runStatus(kSuccessfulRunArn, timeout, poolName);

      // generate report
      runReport(result);
    });

    test('bundle flutter test', () async {
      // note: requires certain env vars to be defined
      final filePath = 'test/sylph_test.yaml';
//    final filePath = 'example/sylph.yaml';
      final config = Config(configPath: filePath);
      // change directory to app
      final origDir = Directory.current;
      Directory.current = 'example';
      await unpackResources(config.tmpDir, true);
      final bundleSize = await bundleFlutterTests(config);
      expect(bundleSize, 5);
      // change back for tests to continue
      Directory.current = origDir;
    });

    test('iterate thru test suites', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = Config(configPath: filePath);
      //    print('config=$config');

      final testSuites = config.testSuites;
      final expectedSuites = [
        {
          'tests': [
            'test_driver/main1_test1.dart',
            'test_driver/main1_test2.dart'
          ],
          'pool_names': ['android pool 1', 'ios pool 1'],
          'job_timeout': 5,
          'main': 'test_driver/main1.dart',
          'test_suite': 'my tests 1'
        },
        {
          'tests': [
            'test_driver/main2_test1.dart',
            'test_driver/main2_test2.dart'
          ],
          'pool_names': ['android pool 1', 'ios pool 1'],
          'job_timeout': 5,
          'main': 'test_driver/main2.dart',
          'test_suite': 'my tests 2'
        }
      ];
      expect(testSuites, expectedSuites);
      for (var testSuite in testSuites) {
        print('Running ${testSuite.name} ...');
        final List devicePools = testSuite.poolNames;
        for (var poolName in devicePools) {
//        print('poolType=$poolType, poolName=$poolName');
          final List tests = testSuite.tests;
          for (var test in tests) {
            // lookup device pool
            final devicePool = config.getDevicePool(poolName);
            if (devicePool == null) {
              throw 'Exception: device pool $poolName not found';
            }
            final poolType = devicePool.deviceType;
            print(
                'running test: $test on $poolType devices in device pool $poolName');
          }
        }
      }
    });
    test('lookup device pool', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = Config(configPath: filePath);
      final poolName = 'android pool 1';
      final devicePool = config.getDevicePool(poolName);
      final expected = {
        'pool_type': 'android',
        'devices': [
          {'model': 'Pixel', 'name': 'Google Pixel', 'os': '8.0.0'},
          {'model': 'Google Pixel 2', 'name': 'Google Pixel 2', 'os': '8.0.0'},
          {'model': 'SM-E7000', 'name': 'Samsung Galaxy E7', 'os': '4.4.4'}
        ],
        'pool_name': 'android pool 1'
      };
      expect(devicePool, expected);
    });

    test('check pool type', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = Config(configPath: filePath);
      final poolName = 'android pool 1';
      final devicePoolInfo = config.getDevicePool(poolName);
      expect(devicePoolInfo.deviceType, enumToStr(DeviceType.android));
    });

    test('download artifacts by run', () {
      final downloadDir = '/tmp/test_artifacts/downloaded_artifacts';
      downloadArtifacts(kSuccessfulRunArn, downloadDir);
      expect(Directory(downloadDir).existsSync(), isTrue);
    });

    test('run device farm command', () {
      final projectName = 'flutter tests';
      var projectInfo = deviceFarmCmd(['list-projects']);
      final projects = projectInfo['projects'];
      final project = projects.firstWhere(
          (project) => project['name'] == projectName,
          orElse: () => null);
      expect(project['name'], projectName);
    });

    test('download artifacts by job', () {
      // get project arn
      // aws devicefarm list-projects
      // get project runs
      // aws devicefarm list-runs --arn <project arn>
      // get artifacts by run, by test suite, by test, etc..
      // aws devicefarm list-artifacts --arn <run arn>
      // download each artifact
      final sylphRunTimestamp = sylphTimestamp();
      final sylphRunName = 'dummy sylph run $sylphRunTimestamp';
      final runName = 'sylph run 2019-08-04 16:22:02.088'; // multiple jobs
      final projectName = kTestProjectName;
      final poolName = 'dummy pool 1'; // only used in dir path
      final downloadDirPrefix = '/tmp/sylph artifacts';

      // list projects
      final projects = deviceFarmCmd(['list-projects'])['projects'];

      // get project arn
      final project = projects.firstWhere(
          (project) => project['name'] == projectName,
          orElse: () => null);
      expect(project, isNotNull);
      final projectArn = project['arn'];
      expect(projectArn, kTestProjectArn);

      // list runs
      final runs = deviceFarmCmd(['list-runs', '--arn', projectArn])['runs'];
//    print('runs=$runs');
      // get a run
      final run = runs.firstWhere((run) => '${run['name']}' == runName,
          orElse: () => null);
      expect(run, isNotNull);
      final runArn = run['arn'];
      expect(runArn, kSuccessfulRunArn);

      // list jobs
      final List jobs = deviceFarmCmd(['list-jobs', '--arn', runArn])['jobs'];
      expect(jobs.length, 1); // find multiple jobs

      // confirm first job
      expect(jobs.first['arn'], kFirstJobArn);

      // generate run download dir
      String runDownloadDir = runArtifactsDirPath(
          downloadDirPrefix, sylphRunName, projectName, poolName);

      // download job artifacts
      downloadJobArtifacts(runArn, runDownloadDir);
      expect(Directory(runDownloadDir).existsSync(), isTrue);
    });

    test('get first device in pool', () async {
      final filePath = 'test/sylph_test.yaml';
      final poolName = 'android pool 1';
      final config = Config(configPath: filePath);
      final devicePoolInfo = config.getDevicePool(poolName);
      final devices = devicePoolInfo.devices;
      final expected = {
        'model': 'Pixel',
        'name': 'Google Pixel',
        'os': '8.0.0'
      };
      expect(devices.first, expected);
    });

    test('generate job progress report for current run', () {
      final runArn = kSuccessfulRunArn;
      final jobsInfo = deviceFarmCmd(['list-jobs', '--arn', runArn])['jobs'];
      for (final jobInfo in jobsInfo) {
//      print('jobInfo=$jobInfo');
        print('\t\t${jobStatus(jobInfo)}');
      }
    });

    test('run jobs in parallel', () async {
      final jobArgs = [
        {'n': 10},
        {'n': 20}
      ];
      List results = await concurrentJobs.runJobs(squareFuture, jobArgs);
      for (int i = 0; i < results.length; i++) {
//      print("squareFuture job #$i: job(${jobArgs[i]}) = ${results[i]}");
        expect(results[i], await squareFuture(jobArgs[i]));
      }
    });

    test('run sylph tests on a device pool in isolate', () async {
      // note: runs on device farm, assumes resources unpacked and bundle created
      final configYaml = '''
        tmp_dir: /tmp/sylph
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
        flavor: dev
        concurrent_runs: true
        project_name: test concurrent runs
        default_job_timeout: 10 
        device_pools:
          - pool_name: android pool 1
            pool_type: android
            devices:
              - name: Google Pixel 2
                model: Google Pixel 2
                os: 8.0.0
          - pool_name: ios pool 1
            pool_type: ios
            devices:
              - name: Apple iPhone X
                model: A1865
                os: 11.4
        test_suites:
          - test_suite: example tests 1
            main: test_driver/main.dart
            tests:
              - test_driver/main_test.dart
            pool_names:
              - android pool 1
              - ios pool 1
            job_timeout: 15
      ''';
      final config = loadYaml(configYaml);

      // pack job args
      final timestamp = sylphTimestamp();
      final testSuite = config['test_suites'].first;
      final poolName = 'android pool 1';
      final projectArn = kTestProjectArn;
      final sylphRunName = 'dummy sylph run $timestamp';
      final sylphRunTimeout = config['sylph_timeout'];
      final jobArgs = packArgs(
        testSuite,
        config,
        poolName,
        projectArn,
        sylphRunName,
        sylphRunTimeout,
        true,
      );

      // for this test change directory
      final origDir = Directory.current;
      Directory.current = 'example';

      // run
      final result =
          await concurrentJobs.runJobs(runSylphJobInIsolate, [jobArgs]);
      expect(result, [
        {'result': true}
      ]);

      // allow other tests to continue
      Directory.current = origDir;
    }, skip: true);

    test('check all sylph devices found', () async {
      // get all sylph devices from sylph.yaml
      final config = Config(configPath: 'example/sylph.yaml');
      // for this test change directory
      final origDir = Directory.current;
      Directory.current = 'example';
      final allSylphDevicesFound = isValidConfig(config, true);
      expect(allSylphDevicesFound, true);
      // allow other tests to continue
      Directory.current = origDir;
    });

    test('sylph duration', () {
      final runTime =
          Duration(hours: 0, minutes: 15, seconds: 34, milliseconds: 123);
      final endTime = DateTime.now().add(runTime);
      final startTime = sylphTimestamp();

      String durationFormatted = sylphRuntimeFormatted(startTime, endTime);
      // rounds to milliseconds
      expect(durationFormatted.contains(RegExp(r'15m:34s:12.ms')), true);
    });
  });
}

/// Test for CI environment.
bool isCI() {
  return Platform.environment['CI'] == 'true';
}

// can be called locally or in an isolate. used in testing.
Future<Map> squareFuture(Map args) {
  int n = args['n'];
  return Future.value({'result': n * n});
}
