import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sylph/src/device_farm.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/src/utils/utils.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args[0] != 'run') {
    printError('Usage: sylph run --config <config_file>');
    exit(1);
  }

  final configIndex = args.indexOf('--config');
  if (configIndex == -1 || configIndex + 1 >= args.length) {
    printError('Please specify a config file with --config');
    exit(1);
  }

  final configPath = args[configIndex + 1];
  if (!fileExists(configPath)) {
    printError('Config file not found: $configPath');
    exit(1);
  }

  try {
    final configStr = readFileAsString(configPath);
    final config = Config(configStr: configStr);

    // Set up project
    final projectName = config.getProjectName();
    final jobTimeout = config.getJobTimeoutMinutes();
    final projectArn = await setupProject(projectName, jobTimeout);
    printStatus('Using project: $projectName');

    // Get device pools
    final pools = config.getDevicePools();
    for (final pool in pools) {
      final poolName = pool['pool_name'] as String;
      final devices = (pool['devices'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((device) => DeviceBase(
                name: device['name'] as String,
                model: device['model'] as String,
                os: device['os'] as String,
                osVersion: device['os_version'] as String,
                arn: device['arn'] as String,
              ))
          .toList();

      final devicePool = DevicePool(name: poolName, devices: devices);
      final poolArn = await setupDevicePool(devicePool, projectArn);
      printStatus('Using device pool: $poolName');

      // Upload app
      final appPath = p.join('example', 'build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk');
      final appArn = await uploadFile(projectArn, appPath, 'ANDROID_APP');
      printStatus('Uploaded app: $appPath');

      // Upload test package
      final testPackagePath = p.join('test', 'example.js');
      final testPackageArn = await uploadFile(
        projectArn,
        testPackagePath,
        'APPIUM_NODE_TEST_PACKAGE',
      );
      printStatus('Uploaded test package: $testPackagePath');

      // Upload test spec
      final testSpecPath = 'test_spec.yaml';
      final testSpecArn = await uploadFile(
        projectArn,
        testSpecPath,
        'APPIUM_NODE_TEST_SPEC',
      );
      printStatus('Uploaded test spec: $testSpecPath');

      // Schedule run
      final runName = '${poolName}_${DateTime.now().millisecondsSinceEpoch}';
      final runArn = await scheduleRun(
        name: runName,
        projectArn: projectArn,
        devicePoolArn: poolArn,
        appArn: appArn,
        testPackageArn: testPackageArn,
        testSpecArn: testSpecArn,
        timeout: jobTimeout,
      );

      printStatus('Started test run: $runName');

      // Wait for run to complete
      String status;
      do {
        await Future<void>.delayed(const Duration(seconds: 30));
        final runStatus = await getRunStatus(runArn);
        status = runStatus['status'] as String;
        printStatus('Run status: $status');
      } while (status != kCompletedRunStatus);

      final result = (await getRunStatus(runArn))['result'] as String;
      if (result != kSuccessResult) {
        printError('Test run failed: $result');
        exit(1);
      }
    }

    printStatus('All tests completed successfully!');
  } catch (e, stackTrace) {
    printError('Error: $e\n$stackTrace');
    exit(1);
  }
}
