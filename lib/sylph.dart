import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sylph/utils.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

enum DeviceType { ios, android }

const kCompletedRunStatus = 'COMPLETED';
const kSuccessResult = 'Passed';

/// Parses a named yaml file.
/// Returns as [Map].
Future<Map> parseYaml(String filePath) async {
  String deviceFarmConfigStr =
      await File(filePath).readAsString(encoding: utf8);
  return loadYaml(deviceFarmConfigStr) as Map;
}

/// Sets up a project for testing.
/// Creates new project if none exists.
/// Returns the project ARN as [String].
String setupProject(String projectName, int jobTimeoutMinutes) {
  // check for existing project
  final projects = deviceFarmCmd(['list-projects'])['projects'];
  final project = projects.firstWhere(
      (project) => project['name'] == projectName,
      orElse: () => null);

  if (project == null) {
    // create new project
    print('Creating project for $projectName ...');
    return deviceFarmCmd([
      'create-project',
      '--name',
      projectName,
      '--default-job-timeout-minutes',
      '$jobTimeoutMinutes'
    ])['project']['arn'];
  } else
    return project['arn'];
}

/// Set up a device pool if named pool does not exist.
/// Returns the device pool ARN as [String].
String setupDevicePool(String projectArn, String poolName, List devices) {
  // check for existing pool
  final pools = deviceFarmCmd([
    'list-device-pools',
    '--arn',
    projectArn,
    '--type',
    'PRIVATE'
  ])['devicePools'];
  final pool =
      pools.firstWhere((pool) => pool['name'] == poolName, orElse: () => null);

  if (pool == null) {
    // create new device pool
    print('Creating new device pool $poolName ...');
    // convert devices to rules
    List rules = deviceSpecToRules(devices);

    final newPool = deviceFarmCmd([
      'create-device-pool',
      '--name',
      poolName,
      '--project-arn',
      projectArn,
      '--rules',
      jsonEncode(rules),
      // number of devices in pool should not exceed number of devices requested
      //        '--max-devices', '${devices.length}'
    ])['devicePool'];
    return newPool['arn'];
  } else
    return pool['arn'];
}

/// Schedules a run.
/// Returns the run ARN as [String].
String scheduleRun(String runName, String projectArn, String appArn,
    String devicePoolArn, String testSpecArn, String testPackageArn) {
  // Schedule run
  return deviceFarmCmd([
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
    // Set per job timeout ???
    //    '--execution-configuration',
    //    'jobTimeoutMinutes=5,accountsCleanup=false,appPackagesCleanup=false,videoCapture=true,skipAppResign=true'
  ])['run']['arn'];
}

/// Tracks run status.
/// Returns final run as [Map].
Map runStatus(String runArn, int timeout) {
  Map run;
  for (int i = 0; i < timeout; i = i + 2) {
    run = deviceFarmCmd([
      'get-run',
      '--arn',
      runArn,
    ])['run'];
    final runStatus = run['status'];

    // print run status
    print('Run status: $runStatus');

    if (runStatus == kCompletedRunStatus) return run;

    sleep(Duration(seconds: 2));
  }
  throw 'Error: run timed-out';
}

/// Runs run report.
void runReport(Map run) {
  // print intro
  print(
      'Run \'${run['name']}\' completed ${run['completedJobs']} of ${run['totalJobs']} jobs.');

  final result = run['result'];

  // print result
  print('  Result: $result');

  // print device minutes
  final deviceMinutes = run['deviceMinutes'];
  if (deviceMinutes != null)
    print(
        '  Device minutes: ${deviceMinutes['total']} (${deviceMinutes['metered']} metered).');

  // print counters
  final counters = run['counters'];
  print('  Counters:\n'
      '    skipped: ${counters['skipped']}\n'
      '    warned: ${counters['warned']}\n'
      '    failed: ${counters['failed']}\n'
      '    stopped: ${counters['stopped']}\n'
      '    passed: ${counters['passed']}\n'
      '    errored: ${counters['errored']}\n'
      '    total: ${counters['total']}\n');

  if (result != kSuccessResult) {
    print('Error: test failed');
    exit(1);
  }
}

/// Finds the ARN of a device.
/// Returns device ARN  as [String].
String findDeviceArn(String name, String model, String os) {
  assert(name != null && model != null && os != null);
  final devices = deviceFarmCmd([
    'list-devices',
  ])['devices'];
  Map device = devices.firstWhere(
      (device) => (device['name'] == name &&
          device['modelId'] == model &&
          device['os'] == os),
      orElse: () =>
          throw 'Error: device does not exist: name=$name, model=$model, os=$os');
  return device['arn'];
}

/// Converts a list of devices to a list of rules.
/// Used for building a device pool.
/// Returns rules as [List].
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

/// Uploads a file to device farm.
/// Returns file ARN as [String].
String uploadFile(String projectArn, String filePath, String fileType) {
  // 1. Create upload
  final upload = deviceFarmCmd([
    'create-upload',
    '--project-arn',
    projectArn,
    '--name',
    p.basename(filePath),
    '--type',
    fileType
  ])['upload'];
  final uploadUrl = upload['url'];
  final uploadArn = upload['arn'];

  // 2. Upload file
  cmd('curl', ['-T', filePath, uploadUrl]);

  // 3. Wait until file upload complete
  for (int i = 0; i < 5; i++) {
    final upload = deviceFarmCmd(['get-upload', '--arn', uploadArn])['upload'];
    sleep(Duration(seconds: 1));
    if (upload['status'] == 'SUCCEEDED')
      break;
    else if (i == 4)
      throw 'Error: file upload failed: file path = \'$filePath\'';
  }
  return uploadArn;
}

/// Downloads artifacts generated by a run.
void downloadArtifacts(String runArn, String artifactsDir) {
  clearDirectory(artifactsDir);
  var artifacts = deviceFarmCmd(
      ['list-artifacts', '--arn', runArn, '--type', 'FILE'])['artifacts'];

  for (final artifact in artifacts) {
    final name = artifact['name'];
    final extension = artifact['extension'];
    final fileUrl = artifact['url'];
    final fileName =
        name.replaceAll(' ', '_') + '.' + Uuid().v1() + '.' + extension;
    final filePath = artifactsDir + '/' + fileName;
    print(filePath);
    cmd('wget', ['-O', filePath, fileUrl]);
  }
}
