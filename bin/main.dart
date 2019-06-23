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

  final localRunTimeout = 720; // todo: allow different timeouts
  final runName = 'android and ios run 1'; // todo: allow different names
  final timestamp = genTimestamp();
  print('Starting AWS Device Farm run \'$runName\' at $timestamp ...');
  print('Config file: $configFilePath');

  // Parse config file
  Map config = await sylph.parseYaml(configFilePath);

  // Setup project (if needed)
  final projectArn =
      sylph.setupProject(config['project_name'], config['default_job_timeout']);

  await run(config, projectArn, runName, localRunTimeout, timestamp);
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
void run(Map config, String projectArn, String runName, int runTimeout,
    DateTime timestamp) async {
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
    // Unpack resources used for building debug .ipa and to bundle tests
    await unpackResources(tmpDir); // todo: remove here or in bundler

    // Bundle tests
    await bundleFlutterTests(config);

    // Initialize device pools and run tests in each pool
    for (final poolName in testSuite['pool_names']) {
      print('\nStarting Device Farm run on pool \'$poolName\'...\n');
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

      // construct artifacts dir for this device farm run
      final runArtifactsDir =
          '${config['artifacts_dir']}/$runName $timestamp/$poolName';

      // run tests and report
      runTests(runName, runTimeout, projectArn, devicePoolArn, appArn,
          testPackageArn, testSpecArn, runArtifactsDir);
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
    appArn = sylph.uploadFile(projectArn, kDebugIpaPath, 'IOS_APP');
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
    String artifactsDir) {
  // Schedule run
  print('Starting run \'$runName\' on AWS Device Farms');
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
