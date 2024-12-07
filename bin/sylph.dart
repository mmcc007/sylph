import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:sylph/src/models/device.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/src/device_farm.dart';
import 'package:sylph/src/utils/tool_base.dart';

const String kConfigFileName = 'sylph.yaml';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('project-name', help: 'Project name')
    ..addOption('device-pool', help: 'Device pool name')
    ..addOption('config-file', defaultsTo: kConfigFileName, help: 'Config file path');

  final argResults = parser.parse(args);
  final configPath = argResults['config-file'] as String;

  if (!File(configPath).existsSync()) {
    printError('Config file not found: $configPath');
    exit(1);
  }

  try {
    final configStr = await File(configPath).readAsString();
    final config = Config(configPath: configPath, configStr: configStr);

    final projectName = argResults['project-name'] as String? ?? config.projectName;
    if (projectName == null) {
      printError('Project name not specified');
      exit(1);
    }

    final devicePoolName = argResults['device-pool'] as String?;
    if (devicePoolName == null) {
      printError('Device pool not specified');
      exit(1);
    }

    final devicePool = config.devicePools?.firstWhere(
      (pool) => pool['pool_name'] == devicePoolName,
      orElse: () => throw Exception('Device pool not found: $devicePoolName'),
    );

    if (devicePool == null) {
      printError('Device pool not found: $devicePoolName');
      exit(1);
    }

    final devices = (devicePool['devices'] as List)
        .map((device) => Device(
              name: device['name'] as String,
              model: device['model'] as String,
              os: device['os'] as String,
              osVersion: device['os_version'] as String,
              arn: device['arn'] as String,
            ))
        .toList();

    final deviceFarm = DeviceFarm();
    await deviceFarm.runTests(
      projectName: projectName,
      devicePool: DevicePool(
        name: devicePoolName,
        devices: devices,
      ),
      testSuite: config.testSuites?.first,
    );
  } catch (e) {
    printError('Error: $e');
    exit(1);
  }
}
