import 'dart:async';
import 'dart:io';

import 'package:sylph/src/bundle.dart';
import 'package:sylph/src/concurrent_jobs.dart';
import 'package:sylph/src/device_farm.dart';
import 'package:sylph/src/devices.dart';
import 'package:sylph/src/sylph_run.dart';
import 'package:sylph/src/utils.dart';
import 'package:sylph/src/validator.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';
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
      await parseYaml(filePath);
    });

    test('get first poolname and devices', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = await parseYaml(filePath);
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
    }, skip: true);

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
          'os': '8.0.0'
//      'os': '11.4'
        }, 'android')
      ];

      // convert devices to rules
      final rules = devicesToRule(devices);
      final expected =
          '[{"attribute": "ARN", "operator": "IN","value": "[\\"arn:aws:devicefarm:us-west-2::device:D125AEEE8614463BAE106865CAF4470E\\",\\"arn:aws:devicefarm:us-west-2::device:6B26991B2257455788C5B8EA3C9F91C4\\"]"}]';
      expect(rules, expected);
    });

    test('setup device pool', () async {
//    final projectArn =
//        'arn:aws:devicefarm:us-west-2:122621792560:project:fb4de03d-c6ac-4d25-bd27-4a59214d2a8b';
      // 'test artifacts download'
      final projectArn =
          'arn:aws:devicefarm:us-west-2:122621792560:project:e1c97f71-f534-432b-9e86-3bd7529e327b';
      final poolName = 'ios pool 1';
      final configFilePath = 'test/sylph_test.yaml';

      Map config = await parseYaml(configFilePath);

      Map devicePoolInfo = getDevicePoolInfo(config['device_pools'], poolName);

      // check for existing pool
      final result = setupDevicePool(devicePoolInfo, projectArn);
      final expected =
          'arn:aws:devicefarm:us-west-2:122621792560:devicepool:e1c97f71-f534-432b-9e86-3bd7529e327b/ab9460cf-fd81-4848-9ae5-643da98937ae';
      expect(result, expected);
    }, skip: true);

    test('monitor successful run progress until complete', () {
      final timeout = 100;
      final poolName = 'dummy pool name';
      final result = runStatus(kSuccessfulRunArn, timeout, poolName);

      // generate report
      runReport(result);
    });

    test('bundle flutter test', () async {
      // note: requires certain env vars to be defined
      final filePath = 'test/sylph_test.yaml';
//    final filePath = 'example/sylph.yaml';
      final config = await parseYaml(filePath);
      // change directory to app
      final origDir = Directory.current;
      Directory.current = 'example';
      await unpackResources(config['tmp_dir'], true);
      final bundleSize = await bundleFlutterTests(config);
      expect(bundleSize, 5);
      // change back for tests to continue
      Directory.current = origDir;
    });

    test('iterate thru test suites', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = await parseYaml(filePath);
//    print('config=$config');

      final List testSuites = config['test_suites'];
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
        print('Running ${testSuite['test_suite']} ...');
        final List devicePools = testSuite['pool_names'];
        for (var poolName in devicePools) {
//        print('poolType=$poolType, poolName=$poolName');
          final List tests = testSuite['tests'];
          for (var test in tests) {
            // lookup device pool
            Map devicePool =
                getDevicePoolInfo(config['device_pools'], poolName);
            if (devicePool == null) {
              throw 'Exception: device pool $poolName not found';
            }
            final poolType = devicePool['pool_type'];
            print(
                'running test: $test on $poolType devices in device pool $poolName');
          }
        }
      }
    });
    test('lookup device pool', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = await parseYaml(filePath);

      final poolName = 'android pool 1';
      Map devicePool = getDevicePoolInfo(config['device_pools'], poolName);
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
      final config = await parseYaml(filePath);
      final poolName = 'android pool 1';
      Map devicePoolInfo = getDevicePoolInfo(config['device_pools'], poolName);
      expect(devicePoolInfo['pool_type'], enumToStr(DeviceType.android));
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
      final config = await parseYaml(filePath);
      final devicePoolInfo =
          getDevicePoolInfo(config['device_pools'], poolName);
      final devices = devicePoolInfo['devices'];
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
//    print('square=$square');
      List results = await runJobs(square, jobArgs);
      for (int i = 0; i < results.length; i++) {
//      print("square job #$i: job(${jobArgs[i]}) = ${results[i]}");
        expect(results[i], square(jobArgs[i]));
      }

      // try again with a future
      results = await runJobs(squareFuture, jobArgs);
      for (int i = 0; i < results.length; i++) {
//      print("squareFuture job #$i: job(${jobArgs[i]}) = ${results[i]}");
        expect(results[i], await squareFuture(jobArgs[i]));
      }
    });

    test('run sylph tests on a device pool in isolate', () async {
      final config = await parseYaml('test/sylph_test.yaml');

      // pack job args
      //Map testSuite, Map config, poolName,
      //    String projectArn, String sylphRunName, int sylphRunTimeout
      final timestamp = sylphTimestamp();
      final testSuite = config['test_suites'].first;
      final poolName = 'android pool 1';
      final projectArn = kTestProjectArn;
      final sylphRunName = 'dummy sylph run $timestamp';
      final sylphRunTimeout = config['sylph_timeout'];
      final jobArgs = packArgs(testSuite, config, poolName, projectArn,
          sylphRunName, sylphRunTimeout);

      // run
      final result = await runJobs(runSylphJobInIsolate, [jobArgs]);
      expect(result, [
        {'result': true}
      ]);
    }, skip: true);

    test('check all sylph devices found', () async {
      // get all sylph devices from sylph.yaml
//    final config = await parseYaml('test/sylph_test.yaml');
      final config = await parseYaml('example/sylph.yaml');
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

    test('substitute MAIN and TESTS for actual debug main and tests', () async {
      final filePath = 'test/sylph_test.yaml';
      final config = await parseYaml(filePath);
      final test_suite = config['test_suites'][0];
      final expectedMainEnvVal = test_suite['main'];
      final expectedTestsEnvVal = test_suite['tests'].join(",");
      final testSpecPath = 'test/test_spec_test.yaml';
      final expected = '''
      # - bin/py.test tests/ --junit-xml \$DEVICEFARM_LOG_DIR/junitreport.xml
      - MAIN=$expectedMainEnvVal
      - TESTS='$expectedTestsEnvVal'
      - cd flutter_app
''';
      setTestSpecEnv(test_suite, testSpecPath);
      expect(File(testSpecPath).readAsStringSync(), expected);
      // restore modified test spec test
      cmd('git', ['checkout', testSpecPath]);
    });
  });

  group('devices', () {
    group('device equality', () {
      test('test for equality between sylph devices', () {
        final name1 = 'name1';
        final name2 = 'name2';
        final model = 'model';
        final os = Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final sylphDevice1 = SylphDevice(name1, model, os, deviceType);
        final sylphDevice2 = SylphDevice(name2, model, os, deviceType);
        expect(sylphDevice1 == Object(), isFalse);
        expect(sylphDevice1 == sylphDevice1, isTrue);
        expect(sylphDevice1 == sylphDevice2, isFalse);
      });

      test('test for equality between device farm devices', () {
        final formFactor = FormFactor.phone;
        final arn1 = 'arn1';
        final arn2 = 'arn2';
        final availability = 'availability';
        final name = 'name';
        final model = 'model';
        final os = Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final deviceFarmDevice1 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor, availability, arn1);
        final deviceFarmDevice2 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor, availability, arn2);
        expect(deviceFarmDevice1 == Object(), isFalse);
        expect(deviceFarmDevice1 == deviceFarmDevice1, isTrue);
        expect(deviceFarmDevice1 == deviceFarmDevice2, isFalse);
      });

      test('test for equality between SylphDevice and DeviceFarmDevice classes',
          () {
        final name = 'name';
        final model = 'model';
        final os = Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final sylphDevice = SylphDevice(name, model, os, deviceType);
        final formFactor = FormFactor.phone;
        final availability = 'availability';
        final arn = 'arn';
        final deviceFarmDevice = DeviceFarmDevice(
            name, model, os, deviceType, formFactor, availability, arn);
        expect(deviceFarmDevice == sylphDevice,
            isTrue); // uses DeviceFarmDevice ==
        expect(sylphDevice == deviceFarmDevice, isTrue); // uses SylphDevice ==

        // device farm device has a different value for a shared member
        final deviceFarmDeviceDiffSharedMember = DeviceFarmDevice(
            'device farm name',
            model,
            os,
            deviceType,
            formFactor,
            availability,
            arn);
        expect(deviceFarmDeviceDiffSharedMember == sylphDevice, isFalse);
        expect(sylphDevice == deviceFarmDeviceDiffSharedMember, isFalse);

        // device farm device has a different value for a unique member
        final deviceFarmDeviceDiffUniqueMember = DeviceFarmDevice(name, model,
            os, deviceType, formFactor, availability, 'device farm arn');
        expect(deviceFarmDeviceDiffUniqueMember == sylphDevice, isTrue);
        expect(sylphDevice == deviceFarmDeviceDiffUniqueMember, isTrue);
      });
    });

    const kOrderedBefore = -1;
    group('device sorting', () {
      test('sort sylph devices', () {
        final name1 = 'name1';
        final name2 = 'name2';
        final model = 'model';
        final os = Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final sylphDevice1 = SylphDevice(name1, model, os, deviceType);
        final sylphDevice2 = SylphDevice(name2, model, os, deviceType);
        expect(sylphDevice1.compareTo(sylphDevice2), kOrderedBefore);
      });

      test('sort device farm devices', () {
        final name = 'name';
        final model = 'model';
        final os = Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final formFactor1 = FormFactor.phone;
        final formFactor2 = FormFactor.tablet;
        final availability = 'availability';
        final arn = 'arn';
        final dfDev1 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor1, availability, arn);
        final dfDevice2 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor2, availability, arn);
        expect(dfDev1.compareTo(dfDevice2), kOrderedBefore);
      });
    });

    group('get devices', () {
      test('get sylph devices from config file', () async {
        final configPath = 'test/sylph_test.yaml';
        final config = await parseYaml(configPath);
        final poolName = 'android pool 1';
        final devicePoolInfo =
            getDevicePoolInfo(config['device_pools'], poolName);
        final expectedFirstDeviceName = devicePoolInfo['devices'][0]['name'];
        final expectedDeviceCount = devicePoolInfo.length;
        final sylphDevices = getSylphDevices(devicePoolInfo);
        expect(sylphDevices[0].name, expectedFirstDeviceName);
        expect(sylphDevices.length, expectedDeviceCount);
        // check sorting
        expect(sylphDevices[0].compareTo(sylphDevices[1]), kOrderedBefore);
      });

      test('get device farm devices from device farm api', () async {
        final deviceFarmDevices = getDeviceFarmDevices();
        expect(deviceFarmDevices[0].compareTo(deviceFarmDevices[1]),
            kOrderedBefore);
        expect(deviceFarmDevices.length, greaterThan(10));
      });

      test('get all device farm devices', () {
        final List<DeviceFarmDevice> deviceFarmDevices = getDeviceFarmDevices();
        expect(deviceFarmDevices.length > 10, isTrue);
//        for (final deviceFarmDevice in deviceFarmDevices) {
//          print(deviceFarmDevice);
//        }
      });

      test('get device farm android devices', () {
        final List<DeviceFarmDevice> androidDevices =
            getDeviceFarmDevicesByType(DeviceType.android);
        expect(androidDevices.length > 10, isTrue);
//        for (final androidDevice in androidDevices) {
//          print(androidDevice);
//        }
      });

      test('get device farm ios devices', () {
        final List<DeviceFarmDevice> iOSDevices =
            getDeviceFarmDevicesByType(DeviceType.ios);
        expect(iOSDevices.length > 10, isTrue);
//        for (final iOSDevice in iOSDevices) {
//          print(iOSDevice);
//        }
      });
    });
  });

  group('unpack resources', () {
    test('unpack a file', () async {
      final srcPath = 'exportOptions.plist';
      final dstDir = '/tmp/test_unpack_file';
      await unpackFile(srcPath, dstDir);
      final dstPath = '$dstDir/$srcPath';
      expect(File(dstPath).existsSync(), isTrue,
          reason: '$dstPath does not exist');
    });

    test('substitute env vars in string', () {
      final env = Platform.environment;
      final envVars = ['TEAM_ID'];
      final expected = () {
        final envs = [];
        for (final envVar in envVars) {
          final envVal = env[envVar];
          expect(envVal, isNotNull);
          envs.add(envVal);
        }
        return envs.join(',');
      };
      String str = envVars.join(',');
      for (final envVar in envVars) {
        str = str.replaceAll(envVar, env[envVar]);
      }
      expect(str, expected());
    });

    test('unpack files with env vars and name/value pairs', () async {
      final envVars = ['TEAM_ID'];
      final filePaths = ['fastlane/Appfile', 'exportOptions.plist'];
      final dstDir = '/tmp/test_env_files';

      // change directory to app to get to ios dir
      final origDir = Directory.current;
      Directory.current = 'example';
      final nameVals = {kAppIdentifier: getAppIdentifier()};
      // change back for tests to continue
      Directory.current = origDir;

      for (final srcPath in filePaths) {
        await unpackFile(srcPath, dstDir, envVars: envVars, nameVals: nameVals);
        final dstPath = '$dstDir/$srcPath';
        expect(File(dstPath).existsSync(), isTrue,
            reason: '$dstPath not found');
      }
    });

    test('find APP_IDENTIFIER', () {
      final expected = 'com.orbsoft.counter';
      // change directory to app
      final origDir = Directory.current;
      Directory.current = 'example';

      String appIdentifier = getAppIdentifier();
      expect(appIdentifier, expected);

      // change back for tests to continue
      Directory.current = origDir;
    });
  });

  group('android only runs', () {
    test('is pool type active', () async {
      final configPath = 'test/sylph_test.yaml';
      final config = await parseYaml(configPath);
      final androidPoolType = DeviceType.android;

      bool isAndroidActive = isPoolTypeActive(config, androidPoolType);

      expect(isAndroidActive, isTrue);
    });

    test('check for valid pool types', () {
      final goodConfigStr = '''
      device_pools:
        - pool_name: android pool 1
          pool_type: android
        - pool_name: ios pool 1
          pool_type: ios
        - pool_name: ios pool 2
          pool_type: ios
      ''';
      Map config = loadYaml(goodConfigStr);
      expect(isValidPoolTypes(config['device_pools']), isTrue);
      final badConfigStr = '''
      device_pools:
        - pool_name: android pool 1
          pool_type: android
        - pool_name: ios pool 1
          pool_type: iosx
        - pool_name: ios pool 2
          pool_type: ios
      ''';
      config = loadYaml(badConfigStr);
      expect(isValidPoolTypes(config['device_pools']), isFalse);
    });
  });
}

// can be called locally or in an isolate. used in testing.
Map square(Map args) {
//  print('running square with args=$args, time=${DateTime.now()}');
  int n = args['n'];
  return {'result': n * n};
}

Future<Map> squareFuture(Map args) {
//  print('running square future with args=$args, time=${DateTime.now()}');
  int n = args['n'];
  return Future.value({'result': n * n});
}
