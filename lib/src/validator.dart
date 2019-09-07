//import 'dart:io';

import 'package:tool_base/tool_base.dart';

import 'bundle.dart';
import 'devices.dart';
import 'utils.dart';

/// Check devices used in tests are valid and available.
/// Also checks tests are present and env vars are set.
bool isValidConfig(Map config, bool isIosPoolTypeActive) {
  // get pool names used in tests
  // and check tests are present
  List poolNames = [];
  for (final testSuite in config['test_suites']) {
    for (final poolName in testSuite['pool_names']) {
      poolNames.add(poolName);
    }
    if (!fs.file(testSuite['main']).existsSync()) {
      printError('Error: test app \`${testSuite['main']}\` not found.');
      exit(1);
    }
    for (final testAppPath in testSuite['tests']) {
      if (!fs.file(testAppPath).existsSync()) {
        printError('Error: test app \`$testAppPath\` not found.');
        exit(1);
      }
    }
  }
  poolNames = poolNames.toSet().toList(); // remove duplicates

  final allSylphDevices = [];
  // iterate the pools
  for (final pool in config['device_pools']) {
    if (poolNames.contains(pool['pool_name'])) {
      // iterate the pool's devices
      for (final sylphDevice in pool['devices']) {
        allSylphDevices.add(loadSylphDevice(sylphDevice, pool['pool_type']));
      }
    }
  }

  // get all job devices
  final allJobDevices = getDeviceFarmDevices();

  // find all matching sylph devices
  final matchingSylphDevices = [];
  final missingSylphDevices = [];
  for (final sylphDevice in allSylphDevices) {
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

  // check for valid pool types
  final isPoolTypesValid = isValidPoolTypes(config['device_pools']);

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
  return missingSylphDevices.isEmpty && !isEnvFail && isPoolTypesValid;
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

/// Check that pool types in [devicePools] are valid.
bool isValidPoolTypes(devicePools) {
  bool isInValidPoolType = false;
  for (final devicePool in devicePools) {
    final poolType = devicePool['pool_type'];
    try {
      stringToEnum(DeviceType.values, poolType);
    } catch (e) {
      printError(
          'Error: \'${devicePool['pool_name']}\' has an invalid pool type: \'$poolType\'.');
      isInValidPoolType = isInValidPoolType || true;
    }
  }
  return !isInValidPoolType;
}
