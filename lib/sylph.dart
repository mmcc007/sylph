import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sylph/utils.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:sprintf/sprintf.dart';

enum DeviceType { ios, android }

const kUploadTimeout = 5;
const kUploadSucceeded = 'SUCCEEDED';
const kCompletedRunStatus = 'COMPLETED';
const kSuccessResult = 'PASSED';

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
    print('Creating new project for \'$projectName\' ...');
    return deviceFarmCmd([
      'create-project',
      '--name',
      projectName,
      '--default-job-timeout-minutes',
      '$jobTimeoutMinutes'
    ])['project']['arn'];
  } else {
    return project['arn'];
  }
}

/// Set up a device pool if named pool does not exist.
/// Returns the device pool ARN as [String].
String setupDevicePool(Map devicePoolInfo, String projectArn) {
  final poolName = devicePoolInfo['pool_name'];
  final devices = devicePoolInfo['devices'];
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
    print('Creating new device pool \'$poolName\' ...');
    // convert devices to a rule
    String rules = devicesToRule(devices);

    final newPool = deviceFarmCmd([
      'create-device-pool',
      '--name',
      poolName,
      '--project-arn',
      projectArn,
      '--rules',
      rules,
      // number of devices in pool should not exceed number of devices requested
      // An error occurred (ArgumentException) when calling the CreateDevicePool operation: A static device pool can not have max devices parameter
//      '--max-devices', '${devices.length}'
    ])['devicePool'];
    return newPool['arn'];
  } else {
    return pool['arn'];
  }
}

/// Schedules a run.
/// Returns the run ARN as [String].
String scheduleRun(
    String runName,
    String projectArn,
    String appArn,
    String devicePoolArn,
    String testSpecArn,
    String testPackageArn,
    int runTimeout) {
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
    '--execution-configuration',
    'jobTimeoutMinutes=$runTimeout,accountsCleanup=false,appPackagesCleanup=false,videoCapture=true,skipAppResign=false'
  ])['run']['arn'];
}

/// Tracks run status.
/// Returns final run status as [Map].
Map runStatus(String runArn, int sylphRunTimeout, String poolName) {
  const timeoutIncrement = 2;
  Map runStatus;
  for (int i = 0; i < sylphRunTimeout; i += timeoutIncrement) {
    runStatus = deviceFarmCmd([
      'get-run',
      '--arn',
      runArn,
    ])['run'];
    final runStatusFlag = runStatus['status'];

    // print run status
    print(
        'Run status on device pool \'$poolName\`: $runStatusFlag (sylph run timeout: $i of $sylphRunTimeout)');

    // print job status' for this run
    final jobsInfo = deviceFarmCmd(['list-jobs', '--arn', runArn])['jobs'];
    for (final jobInfo in jobsInfo) {
      print('\t\t${jobStatus(jobInfo)}');
    }

    if (runStatusFlag == kCompletedRunStatus) return runStatus;

    sleep(Duration(seconds: timeoutIncrement));
  }
  // todo: cancel run on device farm
  throw 'Error: run timed-out';
}

/// Generates string of job status info from a [Map] of job info
String jobStatus(Map job) {
  final jobCounters = job['counters'];
  final deviceMinutes = job['deviceMinutes'];
  return sprintf('device: %-15s, passed: %s, failed: %s, minutes: %s', [
    job['name'],
    jobCounters['passed'],
    jobCounters['failed'],
    deviceMinutes['total']
  ]);
}

/// Runs run report.
/// Returns [bool] for pass/fail of run.
bool runReport(Map run) {
  // print intro
  print(
      'Run \'${run['name']}\' completed ${run['completedJobs']} of ${run['totalJobs']} jobs.');

  final result = run['result'];

  // print result
  print('  Result: $result');

  // print device minutes
  final deviceMinutes = run['deviceMinutes'];
  if (deviceMinutes != null) {
    print(
        '  Device minutes: ${deviceMinutes['total']} (${deviceMinutes['metered']} metered).');
  }
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
    print('Warning: run failed. Continuing...');
    return false;
  }
  return true;
}

/// Finds the ARNs of devices for a [List] of sylph devices.
/// Returns device ARNs as a [List].
List findDevicesArns(List sylphDevices) {
  final deviceArns = [];
  // get all devices
  final jobsDevices = deviceFarmCmd([
    'list-devices',
  ])['devices'];
  for (final sylphDevice in sylphDevices) {
    Map jobDevice = jobsDevices.firstWhere(
        (jobDevice) => (isDeviceEqual(jobDevice, sylphDevice)),
        orElse: () =>
            throw 'Error: device does not exist: ${deviceDesc(sylphDevice)}');
    deviceArns.add(jobDevice['arn']);
  }

  return deviceArns;
}

/// Converts a [List] of sylph devices to a rule.
/// Used for building a device pool.
/// Returns rule as formatted [String].
String devicesToRule(List sylphDevices) {
  return '[{"attribute": "ARN", "operator": "IN","value": "[${formatArns(findDevicesArns(sylphDevices))}]"}]';
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
  for (int i = 0; i < kUploadTimeout; i++) {
    final upload = deviceFarmCmd(['get-upload', '--arn', uploadArn])['upload'];
    sleep(Duration(seconds: 1));
    if (upload['status'] == kUploadSucceeded) {
      return uploadArn;
    }
  }
  throw 'Error: file upload failed: file path = \'$filePath\'';
}

/// Downloads artifacts for each job generated during a run.
void downloadJobArtifacts(String runArn, String runArtifactDir) {
  // list jobs
  final List jobs = deviceFarmCmd(['list-jobs', '--arn', runArn])['jobs'];

  for (final job in jobs) {
    // get sylph device
    final sylphDevice = getSylphDevice(job['device']);

    // generate job artifacts dir and download job artifacts
    downloadArtifacts(job['arn'], jobArtifactsDirPath(runArtifactDir, sylphDevice));
  }
}

/// Downloads artifacts generated during a run.
/// [arn] can be a run, job, suite, or test ARN.
void downloadArtifacts(String arn, String artifactsDir) {
  print('Downloading artifacts to $artifactsDir');
  // create directory
  clearDirectory(artifactsDir);

  final artifacts = deviceFarmCmd(
      ['list-artifacts', '--arn', arn, '--type', 'FILE'])['artifacts'];

  for (final artifact in artifacts) {
    final name = artifact['name'];
    final extension = artifact['extension'];
    final fileUrl = artifact['url'];
    final artifactArn = artifact['arn'];

    // avoid duplicate filenames
    final regExp = RegExp(r'(\/\d*){4}$'); // get last four numbers of arn
    // returns an empty element at start of list that is removed
    final artifactIDs = regExp.stringMatch(artifactArn).split('/')..removeAt(0);

    // use last artifactID to make unique
    final fileName = '$name ${artifactIDs[3]}.$extension'.replaceAll(' ', '_');
    final filePath = '$artifactsDir/$fileName';
    cmd('wget', ['-O', filePath, fileUrl]);
  }
}
