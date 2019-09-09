//import 'dart:io';
import 'package:sylph/src/resources.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'config.dart';
import 'device_farm.dart';

/// Check devices used in tests are valid and available.
/// Also checks tests are present and env vars are set.
bool isValidConfig(Config config, bool isIosPoolTypeActive) {
  // get pool names used in tests
  // and check tests are present

  // get all job devices
  final allJobDevices = getDeviceFarmDevices();

  final matchingSylphDevices = [];
  final missingSylphDevices = [];

  bool isMissingAppFile = false;
  for (final testSuite in config.testSuites) {
    if (!fs.file(testSuite.main).existsSync()) {
      printError('Error: test app \`${testSuite.main}\` not found.');
      isMissingAppFile = true;
    }
    for (final testAppPath in testSuite.tests) {
      if (!fs.file(testAppPath).existsSync()) {
        printError('Error: test driver \`$testAppPath\` not found.');
        isMissingAppFile = true;
      }
    }
    // find all matching sylph devices
    for (final sylphDevice in config.getDevicesInSuite(testSuite.name)) {
      final jobDevice = allJobDevices
          .firstWhere((device) => device == sylphDevice, orElse: () => null);
      if (jobDevice != null) {
        if (jobDevice.availability == 'BUSY') {
          printError('Error: device: \'$jobDevice\' is busy.');
          exit(1);
        }
        matchingSylphDevices.add(jobDevice);
      } else {
        printError('Error: No match found for $sylphDevice.');
        missingSylphDevices.add(sylphDevice);
      }
    }
  }

  // check for valid pool types
  final isPoolTypesValid = config.isValidPoolTypes();

  // check environment vars are present
  bool isEnvFail = false;
  if (isIosPoolTypeActive) {
    isEnvFail = isEnvVarUndefined(kExportOptionsPlistEnvVars);
    // if running in CI
    final envVars = platform.environment;
    if (envVars[kCIEnvVar] != null) {
      isEnvFail = isEnvVarUndefined(kIosCIBuildEnvVars) || isEnvFail;
      isEnvFail = isEnvVarUndefined(kAWSCredentialsEnvVars) || isEnvFail;
    }
  }
  return missingSylphDevices.isEmpty &&
      !isEnvFail &&
      isPoolTypesValid &&
      !isMissingAppFile;
}

/// Check the list of environment variables for undefined.
bool isEnvVarUndefined(List envVars) {
  bool envFail = false;
  final env = platform.environment;
  for (final envVar in envVars) {
    if (env[envVar] == null) {
      printError('Error: $envVar environmental variable is not defined.');
      envFail = true;
    }
  }
  return envFail;
}
