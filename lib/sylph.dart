import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sylph/utils.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

enum DeviceType { ios, android }

const kResourcesUri = 'package:sylph/resources';
const kAppiumTemplate = 'appium_template.zip';
const kTestBundle = 'test_bundle.zip';

/// parse a yaml file to a map
Future<Map> parseYaml(String filePath) async {
  String deviceFarmConfigStr =
      await File(filePath).readAsString(encoding: utf8);
  return loadYaml(deviceFarmConfigStr) as Map;
}

/// Sets up a project for testing.
/// Creates new project if none exists.
/// Returns the project ARN.
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
    print('Creating device pool $poolName ...');
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
/// Returns the run ARN.
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

/// Tracks run status and returns final run.
Map runStatus(String runArn, int timeout) {
  Map run;
  for (int i = 0; i < timeout; i++) {
    run = deviceFarmCmd([
      'get-run',
      '--arn',
      runArn,
    ])['run'];
    final runStatus = run['status'];

    // print run status
    print('Run status: $runStatus');

    if (runStatus == 'COMPLETED')
      break;
    else if (i == timeout - 2) throw 'Error: run timed-out';
    sleep(Duration(seconds: 2));
  }
  return run;
}

/// Run report.
void runReport(Map run) {
  // print intro
  print(
      'Run \'${run['name']}\' completed ${run['completedJobs']} of ${run['totalJobs']} jobs.');

  // print result
  print('  Result: ${run['result']}');

  // print device minutes
  final deviceMinutes = run['deviceMinutes'];
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
}

/// Finds the ARN of a device.
String findDeviceArn(String name, String model, String os) {
  assert(name != null && model != null && os != null);
  final devices = deviceFarmCmd([
    'devicefarm',
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
/// Returns file ARN.
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

/// Bundles Flutter tests using appium template.
/// Resulting bundle is saved on disk in temporary location.
Future bundleFlutterTests(Map config) async {
  final tmpDir = config['tmp_dir'];
  clearDirectory(tmpDir);
  final testBundlePath = '$tmpDir/$kTestBundle';
  await unpackResources(tmpDir);

//  final testSuite = config['test_suites'][0];
//  final appPath = testSuite['app_path'];
  final appPath = Directory.current.path;
//  print('appPath=$appPath');
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
