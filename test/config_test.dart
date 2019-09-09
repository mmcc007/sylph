import 'package:sylph/src/config.dart';
import 'package:sylph/src/base/devices.dart';
import 'package:test/test.dart';
import 'package:tool_base_test/tool_base_test.dart';
import 'package:version/version.dart';

main() {
  group('config', () {
    test('getPoolDevices', () {
      final poolName = 'android pool 1';
      final deviceName = 'Google Pixel 2';
      final deviceModel = 'Google Pixel 2';
      final deviceOs = '8.0.0';
      final configStr = '''
        device_pools:
          - pool_name: $poolName
            pool_type: android
            devices:
              - name: $deviceName
                model: $deviceModel
                os: $deviceOs
      ''';
      final expectedDevices = <SylphDevice>[
        SylphDevice(deviceName, deviceModel, Version.parse(deviceOs),
            DeviceType.android)
      ];
      final config = Config(configStr: configStr);
      expect(config.getPoolDevices(poolName), equals(expectedDevices));
    });

    test('isActivePoolType', () {
      final configStr = '''
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
              # - ios pool 1
            job_timeout: 15
      ''';
      final config = Config(configStr: configStr);
      expect(config.isPoolTypeActive(DeviceType.android), isTrue);
      expect(config.isPoolTypeActive(DeviceType.ios), isFalse);
    });

    test('getPoolType', () {
      final poolNameAndroid = 'android pool 1';
      final poolNameIos = 'ios pool 1';
      final configStr = '''
        tmp_dir: /tmp/sylph
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
        concurrent_runs: true
        project_name: test concurrent runs
        default_job_timeout: 10 
        device_pools:
          - pool_name: $poolNameAndroid
            pool_type: android
            devices:
              - name: Google Pixel 2
                model: Google Pixel 2
                os: 8.0.0
          - pool_name: $poolNameIos
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
              # - ios pool 1
            job_timeout: 15
      ''';
      final config = Config(configStr: configStr);
      expect(config.getPoolType(poolNameAndroid), equals(DeviceType.android));
      expect(config.getPoolType(poolNameIos), equals(DeviceType.ios));
    });

    test('getTestSuites', () {
      final name = 'example tests 1';
      final main = 'test_driver/main.dart';
      final configStr = '''
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
      final expected = [
        TestSuite(name, main, <String>['test_driver/main_test.dart'],
            <String>['android pool 1', 'ios pool 1'], 15)
      ];
      final config = Config(configStr: configStr);
      expect(config.testSuites, equals(expected));
    });

    test('TestSuite equality', () {
      final testSuite1 = TestSuite(
          'test suite1',
          'main1.dart',
          <String>['test_driver/main_test.dart'],
          <String>['android pool 1', 'ios pool 1'],
          15);
      final testSuite2 = TestSuite(
          'test suite1',
          'main1.dart',
          <String>['test_driver/main_test.dart'],
          <String>['android pool 1', 'ios pool 1'],
          15);
      expect(testSuite1, equals(testSuite2));
    });

    test('getDevicesInSuite', () {
      final suiteName = 'example tests 1';
      final configStr = '''
        tmp_dir: /tmp/sylph
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
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
          - test_suite: $suiteName
            main: test_driver/main.dart
            tests:
              - test_driver/main_test.dart
            pool_names:
              - android pool 1
              # - ios pool 1
            job_timeout: 15
      ''';
      final config = Config(configStr: configStr);
      final expected = [
        SylphDevice('Google Pixel 2', 'Google Pixel 2', Version.parse('8.0.0'),
            DeviceType.android)
      ];
      expect(config.getDevicesInSuite(suiteName), equals(expected));
    });

    test('getDevicePool', () {
      final poolName = 'android pool 1';
      final configStr = '''
        device_pools:
          - pool_name: $poolName
            pool_type: android
            devices:
              - name: Google Pixel 2
                model: Google Pixel 2
                os: 8.0.0      
      ''';
      final config = Config(configStr: configStr);
      expect(config.getDevicePool(poolName).name, equals(poolName));
    });
  });

  group('in context', () {
    testUsingContext('isInvalidPoolType', () {
      final configStr = '''
        device_pools:
          - pool_name: android pool 1
            pool_type: androidxx
            devices:
              - name: Google Pixel 2
                model: Google Pixel 2
                os: 8.0.0
      ''';
      final config = Config(configStr: configStr);
      expect(config.isValidPoolTypes(), isFalse);
    });
  });

  group('android only runs', () {
    test('is pool type active', () async {
      final configPath = 'test/sylph_test.yaml';
      final config = Config(configPath: configPath);
      final androidPoolType = DeviceType.android;
      bool isAndroidActive = config.isPoolTypeActive(androidPoolType);
      expect(isAndroidActive, isTrue);
    });
  });
}
