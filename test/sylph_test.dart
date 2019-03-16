import 'dart:convert';
import 'dart:io';

import 'package:sylph/sylph.dart';
import 'package:sylph/utils.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('parse yaml', () async {
    final filePath = 'test/test_sylph.yaml';
    await parseYaml(filePath);
  });

  test('get first poolname and devices', () async {
    final filePath = 'test/test_sylph.yaml';
    final config = await parseYaml(filePath);
    print('config=$config');
    String deviceType = deviceTypeStr(DeviceType.ios);
    print('deviceType=$deviceType');
    final poolName = config['device_pools'][deviceType][0]['device_pool'];
    final devices = config['device_pools'][deviceType][0]['devices'];
    expect(poolName, 'pool 1');
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
    String expected =
        '{"aws_user":"user1","project":"ios_test","test_suites":[{"app":"~/flutter_app","tests":["lib/main.dart"],"device_pool":{"android":null,"ios":["Apple iPhone X"]},"test_suite":"my tests 1"},{"app":"~/flutter_app","tests":["lib/main.dart"],"test_suite":"my tests 2"}],"aws_pass":"pass1","device_pool":{"android":null,"ios":["Apple iPhone X"]}}';
    final Map deviceFarmConfig = loadYaml(deviceFarmConfigStr) as Map;
    expect(deviceFarmConfig, jsonDecode(expected));
  });

  test('setup project', () {
    final projectName = 'flutter test';
    final jobTimeoutMinutes = 5;
    final result = setupProject(projectName, jobTimeoutMinutes);
    print(result);
  });

  test('find device ARN', () {
    final name = 'Apple iPhone X';
    final model = 'A1865';
    final os = '12.0';

    String result = findDeviceArn(name, model, '$os');
    expect(result,
        'arn:aws:devicefarm:us-west-2::device:D125AEEE8614463BAE106865CAF4470E');
  });

  test('convert devices to rules', () {
    final List devices = [
      {'name': 'Apple iPhone X', 'model': 'A1865', 'os': '12.0'}
    ];

    // convert devices to rules
    List rules = deviceSpecToRules(devices);
    print(jsonEncode(rules));
  });

  test('setup device pool', () {
    final projectArn =
        'arn:aws:devicefarm:us-west-2:122621792560:project:fb4de03d-c6ac-4d25-bd27-4a59214d2a8b';
    final poolName = 'flutter test pool 2';
    final List devices = [
      {'name': 'Apple iPhone X', 'model': 'A1865', 'os': '12.0'}
    ];

    // check for existing pool
    String result = setupDevicePool(projectArn, poolName, devices);

    print(result);
  });

  test('monitor run progress until complete', () {
    final runArn =
        'arn:aws:devicefarm:us-west-2:122621792560:run:18ccd74d-2cbc-4d61-a9ca-2fcf656d4d48/cc93dcee-d406-48a6-b8e6-5eaaeb290b11';
    final timeout = 100;
    Map result;

    result = runStatus(runArn, timeout);

    // generate report
    runReport(result);
  });

  test('bundle flutter test', () async {
//    final filePath = 'test/test_sylph.yaml';
    final filePath = 'example/sylph.yaml';
    final config = await parseYaml(filePath);
    Directory.current = 'example';
    await bundleFlutterTests(config);
  });

  test('iterate thru test suites', () async {
    final filePath = 'test/test_sylph.yaml';
    final config = await parseYaml(filePath);
//    print('config=$config');

    final List testSuites = config['test_suites'];
//    print('testSuites=$testSuites');
    for (var testSuite in testSuites) {
      print('Running ${testSuite['test_suite']} ...');
      final List devicePools = testSuite['device_pools'];
      for (var poolName in devicePools) {
//        print('poolType=$poolType, poolName=$poolName');
        final List tests = testSuite['tests'];
        for (var test in tests) {
          // lookup device pool
          Map devicePool = getDevicePoolInfo(config, poolName);
          if (devicePool == null)
            throw 'Exception: device pool $poolName not found';
          final poolType = devicePool['pool_type'];
          print(
              'running test: $test on $poolType devices in device pool $poolName');
        }
      }
    }
  });
  test('lookup device pool', () async {
    final filePath = 'test/test_sylph.yaml';
    final config = await parseYaml(filePath);

    //    for (var pools in devicePools) {
//      if (devicePool != null) return;
//      final List poolList = pools;
//      print('poolList=$poolList');
//      devicePool = poolList.firstWhere((pool) {
//        print(pool['device_pool_name']);
//        return pool['device_pool_name'] == poolName;
//      }, orElse: () => null);
//      print('devicePool=$devicePool');
//    }

    final poolName = 'android pool 1';
    Map devicePool = getDevicePoolInfo(config, poolName);
    print('resulting devicePool=$devicePool');
  });
}
