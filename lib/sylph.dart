import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sylph/utils.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum DeviceType { ios, android }

const resourcesUri = 'package:sylph/resources';
const appiumTemplate = 'appium_template.zip';
const testBundle = 'test_bundle.zip';

/// parse a yaml file to a map
Future<Map> parseYaml(String filePath) async {
  String deviceFarmConfigStr =
      await File(filePath).readAsString(encoding: utf8);
  return loadYaml(deviceFarmConfigStr) as Map;
}

/// Sets up a project for testing.
/// Creates new project if none exists.
String setupProject(String projectName, int jobTimeoutMinutes) {
  // check for existing project
  final List projectList =
      jsonDecode(cmd('aws', ['devicefarm', 'list-projects']))['projects'];
  Map result = projectList.firstWhere(
      (project) => project['name'] == projectName,
      orElse: () => null);

  if (result == null) {
    // create project
    print('Creating project for $projectName ...');
    result = jsonDecode(cmd('aws', [
      'devicefarm',
      'create-project',
      '--name',
      projectName,
      '--default-job-timeout-minutes',
      '$jobTimeoutMinutes'
    ]));
    return result['project']['arn'];
  } else
    return result['arn'];
}

/// Set up a device pool if named pool does not exist.
String setupDevicePool(String projectArn, String poolName, List devices) {
  // check for existing pool
  final List poolList = jsonDecode(cmd('aws', [
    'devicefarm',
    'list-device-pools',
    '--arn',
    projectArn,
    '--type',
    'PRIVATE'
  ]))['devicePools'];
  Map result = poolList.firstWhere((pool) => pool['name'] == poolName,
      orElse: () => null);

  if (result == null) {
    // create device pool
    print('Creating device pool $poolName ...');
    // convert devices to rules
    List rules = deviceSpecToRules(devices);

    result = jsonDecode(cmd('aws', [
      'devicefarm',
      'create-device-pool',
      '--name',
      poolName,
      '--project-arn',
      projectArn,
      '--rules',
      jsonEncode(rules),
      // number of devices in pool should not exceed number of devices requested
      //        '--max-devices', '${devices.length}'
    ]));
    return result['devicePool']['arn'];
  } else
    return result['arn'];
}

/// Schedules a run.
String scheduleRun(String runName, String projectArn, String appArn,
    String devicePoolArn, String testSpecArn, String testPackageArn) {
  // Schedule run
  print('Starting $runName on AWS Device Farms');
  String runArn = jsonDecode(cmd('aws', [
    'devicefarm',
    'schedule-run',
    '--project-arn',
    projectArn,
    '--app-arn',
    appArn,
    '--device-pool-arn',
    devicePoolArn,
    '--name',
    runName,
    '--test',
    'testSpecArn=$testSpecArn,type=APPIUM_PYTHON,testPackageArn=$testPackageArn',
    //    '--execution-configuration',
    //    'jobTimeoutMinutes=5,accountsCleanup=false,appPackagesCleanup=false,videoCapture=true,skipAppResign=true'
  ]))['run']['arn'];
  return runArn;
}

/// Tracks run status.
Map runStatus(String runArn, int timeout) {
  Map result;
  for (int i = 0; i < timeout; i++) {
    result = jsonDecode(cmd('aws', [
      'devicefarm',
      'get-run',
      '--arn',
      runArn,
    ]));
    sleep(Duration(seconds: 2));
    final status = result['run']['status'];

    // print run status
    print('Run status: $status');

    if (status == 'COMPLETED')
      break;
    else if (i == timeout - 2) throw 'Error: run timed-out';
  }
  return result;
}

/// Run report.
void runReport(Map result) {
  // generate report
  final run = result['run'];
  print('run=$run');
  print(
      'Run \'${run['name']}\' completed in ${run['deviceMinutes']['total']} minutes.');
  final counters = run['counters'];
  print('  skipped: ${counters['skipped']}\n'
      '  warned: ${counters['warned']}\n'
      '  skipped: ${counters['skipped']}\n'
      '  failed: ${counters['failed']}\n'
      '  passed: ${counters['passed']}\n'
      '  errored: ${counters['errored']}\n'
      '  total: ${counters['total']}\n');
}

/// Finds the ARN of a device.
String findDeviceArn(String name, String model, String os) {
  assert(name != null && model != null && os != null);
  final List deviceList = jsonDecode(cmd('aws', [
    'devicefarm',
    'list-devices',
  ]))['devices'];
  Map result = deviceList.firstWhere(
      (device) => (device['name'] == name &&
          device['modelId'] == model &&
          device['os'] == os),
      orElse: () =>
          throw 'Error: device does not exist: name=$name, model=$model, os=$os');
  return result['arn'];
}

/// Converts a list of devices to a list of rules.
/// Used for building a device pool.
List deviceSpecToRules(List devices) {
  // convert devices to rules
  final List rules = devices
      .map((device) => {
            'attribute': 'ARN',
            'operator': 'IN',
            'value': '[\"' +
                findDeviceArn(
                    device['name'], device['model'], "${device['os']}") +
                '\"]'
          })
      .toList();
  return rules;
}

/// Upload a file to device farm.
/// Returns file ARN.
String uploadFile(String projectArn, String filePath, String fileType) {
  // 1. Create upload
  String result = cmd('aws', [
    'devicefarm',
    'create-upload',
    '--project-arn',
    projectArn,
    '--name',
    p.basename(filePath),
    '--type',
    fileType
  ]);
  Map resultMap = jsonDecode(result);
  final fileUploadUrl = resultMap['upload']['url'];
  final fileUploadArn = resultMap['upload']['arn'];

  // 2. Upload file
  result = cmd('curl', ['-T', filePath, fileUploadUrl]);

  // 3. Wait until file upload complete
  for (int i = 0; i < 5; i++) {
    result = cmd('aws', ['devicefarm', 'get-upload', '--arn', fileUploadArn]);
    sleep(Duration(seconds: 1));
    resultMap = jsonDecode(result);
    final status = resultMap['upload']['status'];
    if (status == 'SUCCEEDED')
      break;
    else if (i == 4)
      throw 'Error: file upload failed: file path = \'$filePath\'';
  }
  return fileUploadArn;
}

/// Bundles Flutter tests using appium template.
/// Resulting bundle is saved on disk in temporary location.
Future bundleFlutterTests(Map config) async {
  final tmpDir = config['tmp_dir'];
  clearDirectory(tmpDir);
  final testBundlePath = '$tmpDir/$testBundle';
  await unpackResources(tmpDir);

//  final testSuite = config['test_suites'][0];
//  final appPath = testSuite['app_path'];
  final appPath = Directory.current.path;
  print('appPath=$appPath');
  final appName = p.basename(appPath);
  final appDir = p.dirname(appPath);

  // bundle the tests
  cmd(
      'zip',
      [
        '-r',
        testBundlePath,
        '$appName/lib',
        '$appName/pubspec.yaml',
        '$appName/test_driver',
      ],
      '$appDir');

  // bundle the scripts
  cmd('zip', ['-r', testBundlePath, '$appName/script'], '$tmpDir');
}
