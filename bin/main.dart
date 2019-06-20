import 'dart:async';
import 'dart:io';

import 'package:sylph/bundle.dart';
import 'package:sylph/sylph.dart' as sylph;
import 'package:sylph/utils.dart';

const kDebugApkPath = 'build/app/outputs/apk/debug/app-debug.apk';
const kDebugIpaPath = 'build/ios/Debug-iphoneos/Debug_Runner.ipa';
const kConfigFilePath = 'sylph.yaml'; // todo: allow different names

/// Uploads debug app and integration test to device farm and runs test.
main(List<String> arguments) async {
  final runTimeout = 600; // todo: allow different timeouts
//  final runName = 'android run 1'; // todo: allow different names
  final runName = 'ios run 1'; // todo: allow different names
  print('Starting AWS Device Farm run \'$runName\'...');
  print('Config file: $kConfigFilePath');

  // Parse config file
  Map config = await sylph.parseYaml(kConfigFilePath);

  // Setup project (if needed)
  final projectArn =
      sylph.setupProject(config['project_name'], config['default_job_timeout']);

  await run(config, projectArn, runName, runTimeout);
  print('Completed AWS Device Farm run \'$runName\'.');
}

/// Processes config file (subject to change)
/// For each device pool
/// 1. Initialize the device pool
/// 2. Build app for ios or android based on pool type
/// 3. Package and upload the build and tests
/// 4. For each test in each testsuite
///    1. Run tests on device pool
///    2. Report and collect artifacts
void run(Map config, String projectArn, String runName, int runTimeout) async {
  final List testSuites = config['test_suites'];
//    print('testSuites=$testSuites');
  for (var testSuite in testSuites) {
    print('Running \'${testSuite['test_suite']}\' test suite...');

    // todo: update test spec with tests in test suite
    // (currently only allows one test)
//    final List tests = testSuite['tests'];
//    for (var test in tests) {
//      final poolType = devicePoolInfo['pool_type'];
//      print(
//          'bundling test: $test on $poolType devices in device pool $poolName');
//    }

    final tmpDir = config['tmp_dir'];
    // Unpack script used for building debug .ipa and to bundle tests
    await unpackResources(tmpDir);

    // Bundle tests
    await bundleFlutterTests(config);

    // Initialize device pools and run tests in each pool
    final List devicePools = testSuite['device_pools'];
    for (var poolName in devicePools) {
      // lookup device pool info in config file
      Map devicePoolInfo = getDevicePoolInfo(config, poolName);

      // Setup device pool
      String devicePoolArn = setupDevicePool(devicePoolInfo, projectArn);

      // Build debug app for pool type and upload
      final appArn = await buildUploadApp(
          projectArn, devicePoolInfo['pool_type'], testSuite['main'], tmpDir);

      // Upload test suite (in 2 parts)

      // 1. Upload test package
      final testBundlePath = '${config['tmp_dir']}/${kTestBundleName}';
      print('Uploading tests: $testBundlePath ...');
      String testPackageArn = sylph.uploadFile(
          projectArn, testBundlePath, 'APPIUM_PYTHON_TEST_PACKAGE');

      // 2. Upload custom test spec yaml
      final testSpecPath = testSuite['testspec'];
      print('Uploading test specification: $testSpecPath ...');
      String testSpecArn =
          sylph.uploadFile(projectArn, testSpecPath, 'APPIUM_PYTHON_TEST_SPEC');

      // run tests and report
      runTests(runName, runTimeout, projectArn, devicePoolArn, appArn,
          testPackageArn, testSpecArn, '${config['tmp_dir']}/artifacts');
    }
  }
}

/// Builds and uploads app for current pool.
/// Returns app ARN as [String].
Future<String> buildUploadApp(
    String projectArn, String poolType, String mainPath, String tmpDir) async {
  String appArn;
  if (poolType == 'android') {
    await streamCmd('flutter', ['build', 'apk', '-t', mainPath, '--debug']);
    // Upload apk
    print('Uploading debug android app: $kDebugApkPath ...');
    appArn = sylph.uploadFile(projectArn, kDebugApkPath, 'ANDROID_APP');
  } else {
    final envVars = Platform.environment;
    if (envVars['CI'] == 'true') {
      await streamCmd(
          '$tmpDir/script/local_utils.sh', ['--ci', Directory.current.path]);
    }
    await streamCmd('$tmpDir/script/local_utils.sh', ['--build-debug-ipa']);
    // Upload ipa
    print('Uploading iOS app: $kDebugIpaPath ...');
    appArn = sylph.uploadFile(projectArn, '$kDebugIpaPath', 'IOS_APP');
  }
  return appArn;
}

/// Runs the test suite and downloads artifacts.
void runTests(
  String runName,
  int runTimeout,
  String projectArn,
  String devicePoolArn,
  String appArn,
  String testPackageArn,
  String testSpecArn,
  String artifactsDir,
) {
  // Schedule run
  print('Scheduling \'$runName\' on AWS Device Farms');
  String runArn = sylph.scheduleRun(
      runName, projectArn, appArn, devicePoolArn, testSpecArn, testPackageArn);

  // Monitor run progress
  final run = sylph.runStatus(runArn, runTimeout);

  // Output run result
  sylph.runReport(run);

  // Download artifacts
  print('Downloading artifacts...');
  sylph.downloadArtifacts(runArn, artifactsDir);
}

/// Sets-up the named device pool.
/// Returns device pool ARN as [String].
String setupDevicePool(Map devicePoolInfo, String projectArn) {
  final poolName = devicePoolInfo['pool_name'];
  final devices = devicePoolInfo['devices'];
  final devicePoolArn = sylph.setupDevicePool(projectArn, poolName, devices);
  return devicePoolArn;
}
