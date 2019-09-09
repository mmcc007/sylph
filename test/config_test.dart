import 'package:sylph/src/config.dart';
import 'package:sylph/src/devices.dart';
import 'package:sylph/src/utils.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';

main() {
  group('config', () {
    test('getPoolDevices', () {
      final poolName = 'android pool 1';
      final deviceName = 'Google Pixel 2';
      final deviceModel = 'Google Pixel 2';
      final deviceOs = '8.0.0';
      final configStr = '''
        tmp_dir: /tmp/sylph
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
        concurrent_runs: true
        project_name: test concurrent runs
        default_job_timeout: 10 
        device_pools:
          - pool_name: $poolName
            pool_type: android
            devices:
              - name: $deviceName
                model: $deviceModel
                os: $deviceOs
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
      final expectedDevices = <SylphDevice>[
        SylphDevice(deviceName, deviceModel, Version.parse(deviceOs),
            DeviceType.android)
      ];
      final config = Config(configStr: configStr);
      expect(config.getPoolDevices(poolName), equals(expectedDevices));
    });
  });

  group('android only runs', () {
    test('is pool type active', () async {
      final configPath = 'test/sylph_test.yaml';
      final config = await parseYamlFile(configPath);
      final androidPoolType = DeviceType.android;

      bool isAndroidActive = isPoolTypeActive(config, androidPoolType);

      expect(isAndroidActive, isTrue);
    });
  });
}
