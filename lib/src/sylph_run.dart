//import 'dart:io';
import 'dart:async';

import 'package:duration/duration.dart';
import 'package:sylph/src/resources.dart';
import 'package:sylph/src/validator.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'bundle.dart';
import 'base/concurrent_jobs.dart';
import 'config.dart';
import 'context_runner.dart';
import 'device_farm.dart';
import 'base/devices.dart';
import 'base/utils.dart';

const kDebugApkPath = 'build/app/outputs/apk/app.apk';
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
Future<bool> sylphRun(
  String configFilePath,
  String sylphRunName,
  DateTime sylphRunTimestamp,
  bool jobVerbose, {
  String configStr,
}) async {
  bool sylphRunSucceeded = true;

  Config config;
  if (configStr != null) {
    config = Config(configStr: configStr);
  } else {
    config = Config(configPath: configFilePath);
  }
  final isIosPoolTypeActive = config.isPoolTypeActive(DeviceType.ios);
  final isAndroidPoolTypeActive = config.isPoolTypeActive(DeviceType.android);

  // Validate config file
  if (!isValidConfig(config, isIosPoolTypeActive)) {
    printError(
        'Sylph run was terminated due to invalid config file or environment settings.');
    return false;
  }

  final sylphRunTimeout = config.sylphTimeout;

  // Setup project (if needed)
  final projectArn = setupProject(config.projectName, config.defaultJobTimeout);

  // Unpack resources used for building debug .ipa and to bundle tests
  await unpackResources(config.tmpDir, isIosPoolTypeActive);

  // Bundle tests
  bundleFlutterTests(config);

  for (var testSuite in config.testSuites) {
    bool isConcurrentRun() => config.concurrentRuns ?? false;
    printStatus('\nRunning \'${testSuite.name}\' test suite...\n');

    // gather job args
    final jobArgs = <Map>[];

    // Initialize device pools and run tests in each pool
    for (final poolName in testSuite.poolNames) {
      bool runTestsSucceeded = false;
      if (isConcurrentRun()) {
        // gather job args
        jobArgs.add(packArgs(
          testSuite,
          config,
          poolName,
          projectArn,
          sylphRunName,
          sylphRunTimeout,
          jobVerbose,
        ));
      } else {
        runTestsSucceeded = await runSylphJob(
          testSuite,
          config,
          poolName,
          projectArn,
          sylphRunName,
          sylphRunTimeout,
        );
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
Future<bool> runSylphJob(
  TestSuite testSuite,
  Config config,
  poolName,
  String projectArn,
  String sylphRunName,
  int sylphRunTimeout,
) async {
  printStatus(
      'Running test suite \'${testSuite.name}\'  in project \'${config.projectName}\' on pool \'$poolName\' ${isEmpty(config.flavor) ? '' : ' with flavor ${config.flavor}'}...');
  final devicePool = config.getDevicePool(poolName);

  // Setup device pool
  String devicePoolArn = setupDevicePool(devicePool, projectArn);

  final tmpDir = config.tmpDir;

  // Build debug app for pool type and upload
  final appArn = await _buildUploadApp(
    projectArn,
    devicePool.deviceType,
    testSuite.main,
    tmpDir,
    config.flavor,
  );

  // Upload test suite (in 2 parts)

  // 1. Upload test package
  final testBundlePath = '$tmpDir/$kTestBundleZip';
  printStatus('Uploading tests: $testBundlePath ...');
  String testPackageArn = await uploadFile(
      projectArn, testBundlePath, 'APPIUM_PYTHON_TEST_PACKAGE');

  // 2. Upload custom test spec yaml
  final testSpecPath = '$tmpDir/$kAppiumTestSpecName';
  // Substitute MAIN and TESTS for actual debug main and tests from test suite.
  setTestSpecVars(testSuite, testSpecPath);
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
      runArtifactsDirPath(
          config.artifactsDir, sylphRunName, config.projectName, poolName),
      testSuite.jobTimeout,
      poolName);
}

/// Builds and uploads debug app (.ipa or .apk) for current pool type.
/// Returns debug app ARN as [String].
Future<String> _buildUploadApp(String projectArn, DeviceType poolType,
    String mainPath, String tmpDir, String flavor) async {
  String appArn;
  List<String> command;
  final addFlavor = (String flavor) {
    if (!isEmpty(flavor)) {
      command.addAll(['--flavor', flavor]);
    }
  };
  if (poolType == DeviceType.android) {
    printStatus(
        'Building debug .apk from $mainPath${isEmpty(flavor) ? '' : ' with flavor $flavor'}...');
    command = ['flutter', 'build', 'apk', '-t', mainPath, '--debug'];
    addFlavor(flavor);
    await streamCmd(command);
    // Upload apk
    printStatus('Uploading debug android app: $kDebugApkPath ...');
    appArn = await uploadFile(projectArn, kDebugApkPath, 'ANDROID_APP');
  } else {
    printStatus(
        'Building debug .ipa from $mainPath${isEmpty(flavor) ? '' : ' with flavor $flavor'}...');
    if (platform.environment['CI'] == 'true') {
      await streamCmd(
          ['$tmpDir/script/local_utils.sh', '--ci', fs.currentDirectory.path]);
    }
    command = ['$tmpDir/script/local_utils.sh', '--build-debug-ipa'];
    addFlavor(flavor);
    await streamCmd(command);
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

/// Set MAIN and TESTS vars in test spec.
void setTestSpecVars(TestSuite test_suite, String testSpecPath) {
  const kMainEnvName = 'MAIN=';
  const kTestsEnvName = 'TESTS=';
  final mainEnvVal = test_suite.main;
  final testsEnvVal = test_suite.tests.join(",");
  final mainRegExp = RegExp('$kMainEnvName.*');
  final testsRegExp = RegExp('$kTestsEnvName.*');
  String testSpecStr = fs.file(testSpecPath).readAsStringSync();
  testSpecStr =
      testSpecStr.replaceFirst(mainRegExp, '$kMainEnvName$mainEnvVal');
  testSpecStr =
      testSpecStr.replaceAll(testsRegExp, '$kTestsEnvName\'$testsEnvVal\'');
  fs.file(testSpecPath).writeAsStringSync(testSpecStr);
}

/// Runs [runSylphJob] in an isolate.
/// Function signature must match [JobFunction].
Future<Map> runSylphJobInIsolate(Map args) async {
  // unpack args
  final testSuite = args['test_suite'];
  final config = args['config'];
  final poolName = args['pool_name'];
  final projectArn = args['projectArn'];
  final sylphRunName = args['sylph_run_name'];
  final sylphRunTimeout = args['sylph_run_timeout'];
  final jobVerbose = args['jobVerbose'];

  // run runSylphTests
  bool succeeded;
  if (jobVerbose) {
    succeeded = await runInContext<bool>(() {
      return runSylphJob(
        testSuite,
        config,
        poolName,
        projectArn,
        sylphRunName,
        sylphRunTimeout,
      );
    }, overrides: <Type, Generator>{
      Logger: () => VerboseLogger(
          platform.isWindows ? WindowsStdoutLogger() : StdoutLogger()),
    });
  } else {
    succeeded = await runInContext<bool>(() {
      return runSylphJob(
        testSuite,
        config,
        poolName,
        projectArn,
        sylphRunName,
        sylphRunTimeout,
      );
    });
  }

  return {'result': succeeded};
}

/// Pack [runSylphJob] args into [Map].
Map<String, dynamic> packArgs(
  TestSuite testSuite,
  Config config,
  poolName,
  String projectArn,
  String sylphRunName,
  int sylphRunTimeout,
  bool jobVerbose,
) {
  return {
    'test_suite': testSuite,
    'config': config,
    'pool_name': poolName,
    'projectArn': projectArn,
    'sylph_run_name': sylphRunName,
    'sylph_run_timeout': sylphRunTimeout,
    'jobVerbose': jobVerbose,
    'flavor': config.flavor
  };
}
