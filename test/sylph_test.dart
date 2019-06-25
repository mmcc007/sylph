import 'dart:convert';
import 'dart:io';

import 'package:sylph/bundle.dart';
import 'package:sylph/sylph.dart';
import 'package:sylph/utils.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
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
//      {'model': 'A1865xxx', 'name': 'Apple iPhone 7', 'os': '12.0xxx'}
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
  });

  test('find device ARN', () {
    final sylphDevice = {
      'name': 'Apple iPhone X',
      'model': 'A1865',
      'os': '12.0'
    };

    String result = findDevicesArns([sylphDevice]).first;
    expect(result,
        'arn:aws:devicefarm:us-west-2::device:D125AEEE8614463BAE106865CAF4470E');
  });

  test('convert devices to a rule', () {
    final List devices = [
      {'name': 'Apple iPhone X', 'model': 'A1865', 'os': '12.0'},
      {'name': 'Google Pixel', 'model': 'Pixel', 'os': '8.0.0'}
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
    final poolName = 'android pool 1';
    final configFilePath = 'test/sylph_test.yaml';

    Map config = await parseYaml(configFilePath);

    Map devicePoolInfo = getDevicePoolInfo(config['device_pools'], poolName);

    // check for existing pool
    final result = setupDevicePool(devicePoolInfo, projectArn);
    final expected =
        'arn:aws:devicefarm:us-west-2:122621792560:devicepool:e1c97f71-f534-432b-9e86-3bd7529e327b/762d6c56-e189-43ca-aded-bf59c7e20904';
    expect(result, expected);
  });

  test('monitor run progress until complete', () {
    // failed run
//    final runArn =
//        'arn:aws:devicefarm:us-west-2:122621792560:run:18ccd74d-2cbc-4d61-a9ca-2fcf656d4d48/cc93dcee-d406-48a6-b8e6-5eaaeb290b11';
    // successful run
    final runArn =
        'arn:aws:devicefarm:us-west-2:122621792560:job:25b6693b-ecdc-40b6-b736-29de562c18b9/db578606-ebc4-4c1e-a72e-a14b30cbe898/00000';
    final timeout = 100;
    Map result;

    result = runStatus(runArn, timeout);

    // generate report
    runReport(result);
  });

  test('bundle flutter test', () async {
    final filePath = 'test/sylph_test.yaml';
//    final filePath = 'example/sylph.yaml';
    final config = await parseYaml(filePath);
    // change directory to app
    final origDir = Directory.current;
    Directory.current = 'example';
    await unpackResources(config['tmp_dir']);
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
        'tests': ['lib/main.dart'],
        'pool_names': ['android pool 1'],
        'testspec': 'test_spec.yaml',
        'job_timeout': 5,
        'app_path': '/Users/jenkins/flutter_app',
        'test_suite': 'my tests 1'
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
          Map devicePool = getDevicePoolInfo(config['device_pools'], poolName);
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
        {'model': 'Google Pixel 2', 'name': 'Google Pixel 2', 'os': '8.0.0'}
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
    // get project arn
    // aws devicefarm list-projects
    // get project runs
    // aws devicefarm list-runs --arn <project arn>
    // get artifacts by run, by test suite, by test, etc..
    // aws devicefarm list-artifacts --arn <run arn>
    // download each artifact
    DateTime timestamp = genTimestamp();
    final downloadDir = '/tmp/tmp/artifacts xxx $timestamp';
    final runArn =
        'arn:aws:devicefarm:us-west-2:122621792560:run:fef6e39b-8ab0-44f4-b6ae-09115edbce36/42c84f3d-e061-4f23-ac7c-8d5d3a6b8f0f';
    // list artifacts
    downloadArtifacts(runArn, downloadDir);
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
    final sylphRunTimestamp = genTimestamp();
    final sylphRunName = 'dummy sylph run $sylphRunTimestamp';
    final runName = 'sylph run at 2019-06-23 23:44:16.214';
    final projectName = 'test artifacts download';
    final poolName = 'pool 1'; // only used in dir path
    final downloadDirPrefix = '/tmp/sylph artifacts';

    // list projects
    final projects = deviceFarmCmd(['list-projects'])['projects'];

    // get project arn
    final project = projects.firstWhere(
        (project) => project['name'] == projectName,
        orElse: () => null);
    final projectArn = project['arn'];
    expect(projectArn,
        'arn:aws:devicefarm:us-west-2:122621792560:project:e1c97f71-f534-432b-9e86-3bd7529e327b');

    // list runs
    final runs = deviceFarmCmd(['list-runs', '--arn', projectArn])['runs'];
//    print('runs=$runs');
    // get a run
    final run = runs.firstWhere((run) => '${run['name']}' == runName,
        orElse: () => null);
    final runArn = run['arn'];
    expect(runArn,
        'arn:aws:devicefarm:us-west-2:122621792560:run:e1c97f71-f534-432b-9e86-3bd7529e327b/50e59618-6925-45aa-87f6-c5184ef62407');

    // list jobs
    final List jobs = deviceFarmCmd(['list-jobs', '--arn', runArn])['jobs'];
    expect(jobs.length, 2);

    // get job (use first for this test)
    expect(jobs.first['arn'],
        'arn:aws:devicefarm:us-west-2:122621792560:job:e1c97f71-f534-432b-9e86-3bd7529e327b/50e59618-6925-45aa-87f6-c5184ef62407/00000');

    // generate run download dir
    String runDownloadDir = generateRunArtifactsDir(
        downloadDirPrefix, sylphRunName, projectName, poolName);

    // download job artifacts
    downloadJobArtifacts(runArn, runDownloadDir);
  });

  test('get first device in pool', () async {
    final filePath = 'test/sylph_test.yaml';
    final poolName = 'android pool 1';
    final config = await parseYaml(filePath);
    final devicePoolInfo = getDevicePoolInfo(config['device_pools'], poolName);
    final devices = devicePoolInfo['devices'];
    final expected = {'model': 'Pixel', 'name': 'Google Pixel', 'os': '8.0.0'};
    expect(devices.first, expected);
  });
}
