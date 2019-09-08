import 'dart:async';
//import 'dart:io';

import 'package:duration/duration.dart';
import 'package:sylph/src/resources.dart';
import 'package:sylph/src/validator.dart';
import 'package:tool_base/tool_base.dart';

import 'bundle.dart';
import 'concurrent_jobs.dart';
import 'config.dart';
import 'device_farm.dart';
import 'devices.dart';
import 'utils.dart';

const kDebugApkPath = 'build/app/outputs/apk/debug/app-debug.apk';
const kDebugIpaPath = 'build/ios/Debug-iphoneos/Debug_Runner.ipa';

/// Processes config file (subject to change).
/// For each device pool:
/// 1. Initialize the device pool.
/// 2. Build app for ios or android based on pool type.
/// 3. Upload the build.
/// 4. For each test in each testsuite.
///    1. Run tests on each device in device pool.
///    2. Report and collect artifacts for each device.
/// Returns [Future<bool>] for pass or fail.
Future<bool> sylphRun(String configFilePath, String sylphRunName,
    DateTime sylphRunTimestamp, bool jobVerbose,
    {String configStr}) async {
  bool sylphRunSucceeded = true;

  Map config;
  if (configStr != null) {
    config = await parseYamlStr(configStr);
  } else {
    // Parse config file
    config = await parseYamlFile(configFilePath);
  }
  // Check if running on iOS and/or android pools
  final isIosPoolTypeActive = isPoolTypeActive(config, DeviceType.ios);
  final isAndroidPoolTypeActive = isPoolTypeActive(config, DeviceType.android);

  // Validate config file
  if (!isValidConfig(config, isIosPoolTypeActive)) {
    printError(
        'Sylph run was terminated due to invalid config file or environment settings.');
    return false;
  }

  final sylphRunTimeout = config['sylph_timeout'];

  // Setup project (if needed)
  final projectArn =
      setupProject(config['project_name'], config['default_job_timeout']);

  // Unpack resources used for building debug .ipa and to bundle tests
  await unpackResources(config['tmp_dir'], isIosPoolTypeActive);

  // Bundle tests
  bundleFlutterTests(config);

  // gather job args
  final jobArgs = <Map>[];

  bool isConcurrentRun() => config['concurrent_runs'] ?? false;
  for (var testSuite in config['test_suites']) {
    printStatus('\nRunning \'${testSuite['test_suite']}\' test suite...\n');

    // Initialize device pools and run tests in each pool
    for (final poolName in testSuite['pool_names']) {
      bool runTestsSucceeded = false;
      if (isConcurrentRun()) {
        // gather job args
        jobArgs.add(packArgs(testSuite, config, poolName, projectArn,
            sylphRunName, sylphRunTimeout, jobVerbose));
      } else {
        runTestsSucceeded = await runSylphJob(testSuite, config, poolName,
            projectArn, sylphRunName, sylphRunTimeout);
        // track sylph run success
        if (sylphRunSucceeded & !runTestsSucceeded) {
          sylphRunSucceeded = false;
        }
      }
    }

    // run concurrently
    if (isConcurrentRun()) {
      if (isIosPoolTypeActive && isAndroidPoolTypeActive) {
        printStatus('Running tests concurrently on iOS and Android pools...');
      } else {
        if (isIosPoolTypeActive && !isAndroidPoolTypeActive) {
          printStatus('Running tests concurrently on iOS pools...');
        } else if (!isIosPoolTypeActive && isAndroidPoolTypeActive) {
          printStatus('Running tests concurrently on Android pools...');
        }
      }
      final results = await concurrentJobs.runJobs(
        runSylphJobInIsolate,
        jobArgs,
      );
      printStatus('results=$results');
      // process results
      for (final result in results) {
        if (sylphRunSucceeded & result['result'] != true) {
          sylphRunSucceeded = false;
        }
      }
      printStatus('Concurrent runs completed.');
    }
  }
  return sylphRunSucceeded;
}

/// Run sylph tests on a pool of devices using a device farm run.
Future<bool> runSylphJob(Map testSuite, Map config, poolName, String projectArn,
    String sylphRunName, int sylphRunTimeout) async {
  printStatus(
      'Running test suite \'${testSuite['test_suite']}\'  in project \'${config['project_name']}\' on pool \'$poolName\'...');
  // lookup device pool info in config file
  Map devicePoolInfo = getDevicePoolInfo(config['device_pools'], poolName);

  // Setup device pool
  String devicePoolArn = setupDevicePool(devicePoolInfo, projectArn);

  final tmpDir = config['tmp_dir'];

  // Build debug app for pool type and upload
  final appArn = await _buildUploadApp(
      projectArn, devicePoolInfo['pool_type'], testSuite['main'], tmpDir);

  // Upload test suite (in 2 parts)

  // 1. Upload test package
  final testBundlePath = '$tmpDir/$kTestBundleName';
  printStatus('Uploading tests: $testBundlePath ...');
  String testPackageArn = await uploadFile(
      projectArn, testBundlePath, 'APPIUM_PYTHON_TEST_PACKAGE');

  // 2. Upload custom test spec yaml
  final testSpecPath = '$tmpDir/$kAppiumTestSpecName';
  // Substitute MAIN and TESTS for actual debug main and tests from test suite.
  setTestSpecEnv(testSuite, testSpecPath);
  printStatus('Uploading test specification: $testSpecPath ...');
  String testSpecArn =
      await uploadFile(projectArn, testSpecPath, 'APPIUM_PYTHON_TEST_SPEC');

  // run tests and report
  return _runTests(
      sylphRunName,
      sylphRunTimeout,
      projectArn,
      devicePoolArn,
      appArn,
      testPackageArn,
      testSpecArn,
      // construct artifacts dir path for device farm run
      runArtifactsDirPath(config['artifacts_dir'], sylphRunName,
          config['project_name'], poolName),
      testSuite['job_timeout'],
      poolName);
}

/// Builds and uploads debug app (.ipa or .apk) for current pool type.
/// Returns debug app ARN as [String].
Future<String> _buildUploadApp(
    String projectArn, String poolType, String mainPath, String tmpDir) async {
  String appArn;
  if (poolType == 'android') {
    printStatus('Building debug .apk from $mainPath...');
    await streamCmd(['flutter', 'build', 'apk', '-t', mainPath, '--debug']);
    // Upload apk
    printStatus('Uploading debug android app: $kDebugApkPath ...');
    appArn = await uploadFile(projectArn, kDebugApkPath, 'ANDROID_APP');
  } else {
    printStatus('Building debug .ipa from $mainPath...');
    if (platform.environment['CI'] == 'true') {
      await streamCmd(
          ['$tmpDir/script/local_utils.sh', '--ci', fs.currentDirectory.path]);
    }
    await streamCmd(['$tmpDir/script/local_utils.sh', '--build-debug-ipa']);
    // Upload ipa
    printStatus('Uploading debug iOS app: $kDebugIpaPath ...');
    appArn = await uploadFile(projectArn, kDebugIpaPath, 'IOS_APP');
  }
  return appArn;
}

/// Runs the test suite on each device in device pool and downloads artifacts.
/// Returns [bool] on pass/fail.
Future<bool> _runTests(
    String runName,
    int sylphRunTimeout,
    String projectArn,
    String devicePoolArn,
    String appArn,
    String testPackageArn,
    String testSpecArn,
    String artifactsDir,
    int jobTimeout,
    poolName) async {
  bool runSucceeded = false;
  // Schedule run
  printStatus('Starting run \'$runName\' on AWS Device Farms...');
  String runArn = scheduleRun(runName, projectArn, appArn, devicePoolArn,
      testSpecArn, testPackageArn, jobTimeout);

  // Monitor run progress
  final run = runStatus(runArn, sylphRunTimeout, poolName);

  // Output run result
  runSucceeded = runReport(await run);

  // Download artifacts
  printStatus('Downloading artifacts...');
  downloadJobArtifacts(runArn, artifactsDir);
  return runSucceeded;
}

/// Formats the sylph runtime, rounded to milliseconds.
String sylphRuntimeFormatted(DateTime startTime, DateTime endTime) {
  final duration = endTime.difference(startTime);
  final durationFormatted = prettyDuration(duration,
      tersity: DurationTersity.millisecond,
      delimiter: ':',
      spacer: '',
      abbreviated: true);
  return durationFormatted;
}

/// Generates timestamp as [DateTime] in milliseconds
DateTime sylphTimestamp() {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch);
  return timestamp;
}

/// Set MAIN and TESTS env vars in test spec.
void setTestSpecEnv(Map test_suite, String testSpecPath) {
  const kMainEnvName = 'MAIN=';
  const kTestsEnvName = 'TESTS=';
  final mainEnvVal = test_suite['main'];
  final testsEnvVal = test_suite['tests'].join(",");
  final mainRegExp = RegExp('$kMainEnvName.*');
  final testsRegExp = RegExp('$kTestsEnvName.*');
  String testSpecStr = fs.file(testSpecPath).readAsStringSync();
  testSpecStr =
      testSpecStr.replaceFirst(mainRegExp, '$kMainEnvName$mainEnvVal');
  testSpecStr =
      testSpecStr.replaceAll(testsRegExp, '$kTestsEnvName\'$testsEnvVal\'');
  fs.file(testSpecPath).writeAsStringSync(testSpecStr);
}
