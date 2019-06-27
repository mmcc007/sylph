import 'dart:async';
import 'dart:io';

import 'bundle.dart';
import 'concurrent_jobs.dart';
import 'device_farm.dart';
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
Future<bool> sylphRun(Map config, String projectArn, String sylphRunName,
    int sylphRunTimeout, DateTime sylphRunTimestamp) async {
  bool sylphRunSucceeded = true;

  // Unpack resources used for building debug .ipa and to bundle tests
  await unpackResources(config['tmp_dir']);

  // Bundle tests
  await bundleFlutterTests(config);

  // gather job args
  final jobArgs = [];

  for (var testSuite in config['test_suites']) {
    print('\nRunning \'${testSuite['test_suite']}\' test suite...\n');

    // todo: update test spec with tests in test suite
    // (currently only allows one test)
//    final List tests = testSuite['tests'];
//    for (var test in tests) {
//      final poolType = devicePoolInfo['pool_type'];
//      print(
//          'bundling test: $test on $poolType devices in device pool $poolName');
//    }

    // Initialize device pools and run tests in each pool
    for (final poolName in testSuite['pool_names']) {
      bool runTestsSucceeded = false;
      if (config['concurrent_runs']) {
        // schedule each run
        jobArgs.add(packArgs(testSuite, config, poolName, projectArn,
            sylphRunName, sylphRunTimeout));
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
    if (config['concurrent_runs']) {
      print('Running tests concurrently on iOS and Android pools...');
      final results = await runJobs(runSylphJobInIsolate, jobArgs);
      print('results=$results');
      // process results
      for (final result in results) {
        if (sylphRunSucceeded & result['result'] != true) {
          sylphRunSucceeded = false;
        }
      }
      print('Concurrent runs completed.');
    }
  }
  return sylphRunSucceeded;
}

/// Run sylph tests on a pool of devices using a device farm run.
Future<bool> runSylphJob(Map testSuite, Map config, poolName, String projectArn,
    String sylphRunName, int sylphRunTimeout) async {
  print(
      'Running test suite \'${testSuite['test_suite']}\'  in project \'${config['project_name']}\' on pool \'$poolName\'...');
  // lookup device pool info in config file
  Map devicePoolInfo = getDevicePoolInfo(config['device_pools'], poolName);

  // Setup device pool
  String devicePoolArn = setupDevicePool(devicePoolInfo, projectArn);

  // Build debug app for pool type and upload
  final appArn = await _buildUploadApp(projectArn, devicePoolInfo['pool_type'],
      testSuite['main'], config['tmp_dir']);

  // Upload test suite (in 2 parts)

  // 1. Upload test package
  final testBundlePath = '${config['tmp_dir']}/${kTestBundleName}';
  print('Uploading tests: $testBundlePath ...');
  String testPackageArn =
      uploadFile(projectArn, testBundlePath, 'APPIUM_PYTHON_TEST_PACKAGE');

  // 2. Upload custom test spec yaml
  final testSpecPath = testSuite['testspec'];
  print('Uploading test specification: $testSpecPath ...');
  String testSpecArn =
      uploadFile(projectArn, testSpecPath, 'APPIUM_PYTHON_TEST_SPEC');

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
    print('Building debug .apk from $mainPath...');
    await streamCmd('flutter', ['build', 'apk', '-t', mainPath, '--debug']);
    // Upload apk
    print('Uploading debug android app: $kDebugApkPath ...');
    appArn = uploadFile(projectArn, kDebugApkPath, 'ANDROID_APP');
  } else {
    print('Building debug .ipa from $mainPath...');
    if (Platform.environment['CI'] == 'true') {
      await streamCmd(
          '$tmpDir/script/local_utils.sh', ['--ci', Directory.current.path]);
    }
    await streamCmd('$tmpDir/script/local_utils.sh', ['--build-debug-ipa']);
    // Upload ipa
    print('Uploading debug iOS app: $kDebugIpaPath ...');
    appArn = uploadFile(projectArn, kDebugIpaPath, 'IOS_APP');
  }
  return appArn;
}

/// Runs the test suite on each device in device pool and downloads artifacts.
/// Returns [bool] on pass/fail.
bool _runTests(
    String runName,
    int sylphRunTimeout,
    String projectArn,
    String devicePoolArn,
    String appArn,
    String testPackageArn,
    String testSpecArn,
    String artifactsDir,
    int jobTimeout,
    poolName) {
  bool runSucceeded = false;
  // Schedule run
  print('Starting run \'$runName\' on AWS Device Farms...');
  String runArn = scheduleRun(runName, projectArn, appArn, devicePoolArn,
      testSpecArn, testPackageArn, jobTimeout);

  // Monitor run progress
  final run = runStatus(runArn, sylphRunTimeout, poolName);

  // Output run result
  runSucceeded = runReport(run);

  // Download artifacts
  print('Downloading artifacts...');
  downloadJobArtifacts(runArn, artifactsDir);
  return runSucceeded;
}
