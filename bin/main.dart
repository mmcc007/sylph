import 'package:sylph/sylph.dart' as sylph;
import 'package:sylph/utils.dart';

const kDebugApkPath = 'build/app/outputs/apk/debug/app-debug.apk';
const kDebugIpaPath = 'build/ios/Debug-iphoneos/Runner.ipa';
const kConfigFilePath = 'sylph.yaml';

/// Uploads debug app and integration test to device farm and runs test.
main(List<String> arguments) async {
  final runTimeout = 1000;
  final runName = 'android run 1';
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

/// Processes config file
/// For each device pool and each test in each testsuite
/// 1. Initialize the device pool
/// 2. Prepare build for ios or android based on pool type
/// 3. Package and upload the build and tests
/// 4. Run tests on device pool
/// 3. Report and collect artifacts
void run(Map config, String projectArn, String runName, int runTimeout) async {
  final List testSuites = config['test_suites'];
//    print('testSuites=$testSuites');
  for (var testSuite in testSuites) {
    print('Running \'${testSuite['test_suite']}\' test suite...');

    // todo: update test spec with tests from config
//    final List tests = testSuite['tests'];
//    for (var test in tests) {
//      final poolType = devicePoolInfo['pool_type'];
//      print(
//          'bundling test: $test on $poolType devices in device pool $poolName');
//    }

    // Bundle tests
    await sylph.bundleFlutterTests(config);

    // Initialize device pools and run tests in each pool
    final List devicePools = testSuite['device_pools'];
    for (var poolName in devicePools) {
      // lookup device pool
      Map devicePoolInfo = getDevicePoolInfo(config, poolName);
      if (devicePoolInfo == null)
        throw 'Error: device pool $poolName not found';

      // Setup device pool
      String devicePoolArn = setupDevicePool(config, projectArn);

      // Build debug app for pool type and upload
      String appArn;
      if (devicePoolInfo['pool_type'] == enumToStr(sylph.DeviceType.android)) {
        cmd('flutter', ['build', 'apk', '-t', testSuite['main'], '--debug'],
            '.', false);
        // Upload apk
        appArn = uploadBuild(projectArn, sylph.DeviceType.android);
      } else {
        cmd('flutter', ['build', 'ios', '-t', testSuite['main'], '--debug'],
            '.', false);
        // Upload ipa
        appArn = uploadBuild(projectArn, sylph.DeviceType.ios);
      }

      // Upload test artifact (in 2 parts)
      // Upload test package
      final testBundlePath = '${config['tmp_dir']}/${sylph.kTestBundle}';
      print('Uploading tests: $testBundlePath ...');
      String testPackageArn = sylph.uploadFile(
          projectArn, testBundlePath, 'APPIUM_PYTHON_TEST_PACKAGE');

      // Upload custom test spec yaml
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

String uploadBuild(String projectArn, sylph.DeviceType deviceType) {
  String appArn;
  if (deviceType == sylph.DeviceType.android) {
    // Upload apk
    print('Uploading debug android app: $kDebugApkPath ...');
    appArn = sylph.uploadFile(projectArn, kDebugApkPath, 'ANDROID_APP');
  } else {
    print('Uploading debug iOS app: $kDebugIpaPath ...');
    appArn = sylph.uploadFile(projectArn, kDebugApkPath, 'IOS_APP');
  }
  return appArn;
}

String setupDevicePool(Map config, String projectArn) {
  // Setup device pool
//  final deviceType = deviceTypeStr(sylph.DeviceType.android);
  final poolName = config['device_pools'][0]['pool_name'];
  final devices = config['device_pools'][0]['devices'];
  final devicePoolArn = sylph.setupDevicePool(projectArn, poolName, devices);
  return devicePoolArn;
}
