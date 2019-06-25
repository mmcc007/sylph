import 'dart:async';
import 'dart:io';

import 'package:sylph/bundle.dart';
import 'package:sylph/sylph.dart' as sylph;
import 'package:sylph/utils.dart';
import 'package:args/args.dart';

const usage = 'usage: sylph [--help] [--config <config file>]';
const sampleUsage = 'sample usage: sylph';

const kDebugApkPath = 'build/app/outputs/apk/debug/app-debug.apk';
const kDebugIpaPath = 'build/ios/Debug-iphoneos/Debug_Runner.ipa';

/// Uploads debug app and integration test to device farm and runs test.
main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final helpArg = 'help';
  final ArgParser argParser = new ArgParser(allowTrailingOptions: false)
    ..addOption(configArg,
        abbr: 'c',
        defaultsTo: 'sylph.yaml',
        help: 'Path to config file.',
        valueHelp: 'sylph.yaml')
    ..addFlag(helpArg,
        help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }

  // show help
  if (argResults[helpArg]) {
    _showUsage(argParser);
    exit(0);
  }

  // validate args
  final configFilePath = argResults[configArg];
  final file = File(configFilePath);
  if (!await file.exists()) {
    _handleError(argParser, "File not found: $configFilePath");
  }

  final timestamp = genTimestamp();
  final sylphRunName = 'sylph run $timestamp';
  print('Starting Sylph run \'$sylphRunName\' on AWS Device Farm ...');
  print('Config file: $configFilePath');

  // Parse config file
  Map config = await sylph.parseYaml(configFilePath);

  final sylphRunTimeout = config['sylph_timeout'];

  // Setup project (if needed)
  final projectArn =
      sylph.setupProject(config['project_name'], config['default_job_timeout']);

  print('Completed Sylph run \'$sylphRunName\'.');
  final sylphRunSucceeded = await sylphRun(
      config, projectArn, sylphRunName, sylphRunTimeout, timestamp);
  if (sylphRunSucceeded) {
    print('Sylph run \'$sylphRunName\' suceeded.');
    exit(0);
  } else {
    print('Sylph run \'$sylphRunName\' failed.');
    exit(1);
  }
}

/// Processes config file (subject to change).
/// For each device pool:
/// 1. Initialize the device pool.
/// 2. Build app for ios or android based on pool type.
/// 3. Package and upload the build and tests.
/// 4. For each test in each testsuite.
///    1. Run tests on device pool.
///    2. Report and collect artifacts.
/// Returns [Future<bool>] for pass or fail.
Future<bool> sylphRun(Map config, String projectArn, String sylphRunName,
    int sylphRunTimeout, DateTime sylphRunTimestamp) async {
  bool sylphRunSucceeded = true;
  // sylph staging dir
  final tmpDir = config['tmp_dir'];

  // Unpack resources used for building debug .ipa and to bundle tests
  await unpackResources(tmpDir);

  // Bundle tests
  await bundleFlutterTests(config);

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
      print(
          'Running test suite \'${testSuite['test_suite']}\'  in project \'${config['project_name']}\' on pool \'$poolName\'...');
      // lookup device pool info in config file
      Map devicePoolInfo = getDevicePoolInfo(config['device_pools'], poolName);

      // Setup device pool
      String devicePoolArn = sylph.setupDevicePool(devicePoolInfo, projectArn);

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

      // construct artifacts dir for device farm run
      final runArtifactsDir = generateRunArtifactsDir(config['artifacts_dir'],
          sylphRunName, config['project_name'], poolName);

      // run tests and report
      final runSucceeded = runTests(
          sylphRunName,
          sylphRunTimeout,
          projectArn,
          devicePoolArn,
          appArn,
          testPackageArn,
          testSpecArn,
          runArtifactsDir,
          testSuite['job_timeout'],
          poolName);

      // track sylph run success
      if (sylphRunSucceeded & !runSucceeded) {
        sylphRunSucceeded = false;
      }
    }
  }
  return sylphRunSucceeded;
}

/// Builds and uploads debug app (.ipa or .apk) for current pool type.
/// Returns debug app ARN as [String].
Future<String> buildUploadApp(
    String projectArn, String poolType, String mainPath, String tmpDir) async {
  String appArn;
  if (poolType == 'android') {
    print('Building debug .apk from $mainPath...');
    await streamCmd('flutter', ['build', 'apk', '-t', mainPath, '--debug']);
    // Upload apk
    print('Uploading debug android app: $kDebugApkPath ...');
    appArn = sylph.uploadFile(projectArn, kDebugApkPath, 'ANDROID_APP');
  } else {
    print('Building debug .ipa from $mainPath...');
    if (Platform.environment['CI'] == 'true') {
      await streamCmd(
          '$tmpDir/script/local_utils.sh', ['--ci', Directory.current.path]);
    }
    await streamCmd('$tmpDir/script/local_utils.sh', ['--build-debug-ipa']);
    // Upload ipa
    print('Uploading debug iOS app: $kDebugIpaPath ...');
    appArn = sylph.uploadFile(projectArn, kDebugIpaPath, 'IOS_APP');
  }
  return appArn;
}

/// Runs the test suite on each device in device pool and downloads artifacts.
/// Returns [bool] on pass/fail.
bool runTests(
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
  String runArn = sylph.scheduleRun(runName, projectArn, appArn, devicePoolArn,
      testSpecArn, testPackageArn, jobTimeout);

  // Monitor run progress
  final run = sylph.runStatus(runArn, sylphRunTimeout, poolName);

  // Output run result
  runSucceeded = sylph.runReport(run);

  // Download artifacts
  print('Downloading artifacts...');
  sylph.downloadJobArtifacts(runArn, artifactsDir);
  return runSucceeded;
}

void _handleError(ArgParser argParser, String msg) {
  stderr.writeln(msg);
  _showUsage(argParser);
  exit(1);
}

void _showUsage(ArgParser argParser) {
  print('$usage');
  print('\n$sampleUsage\n');
  print(argParser.usage);
}
