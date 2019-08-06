import 'dart:io';

import 'package:version/version.dart';

import 'devices.dart';
import 'utils.dart';

/// Check devices used in tests are valid and available.
/// Also checks tests are present.
bool isValidConfig(Map config) {
  // get pool names used in tests
  // and check tests are present
  List poolNames = [];
  for (final testSuite in config['test_suites']) {
    for (final poolName in testSuite['pool_names']) {
      poolNames.add(poolName);
    }
    if (!File(testSuite['main']).existsSync()) {
      stderr.writeln('Error: test app \`${testSuite['main']}\` not found.');
      exit(1);
    }
    for (final testAppPath in testSuite['tests']) {
      if (!File(testAppPath).existsSync()) {
        stderr.writeln('Error: test app \`$testAppPath\` not found.');
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
        allSylphDevices.add(getSylphDevice(sylphDevice, pool['pool_type']));
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
        stderr.writeln('Error: device: \'$jobDevice\' is busy.');
        exit(1);
      }
      matchingSylphDevices.add(jobDevice);
    } else {
      stderr.writeln('Error: No match found for $sylphDevice.');
      missingSylphDevices.add(sylphDevice);
    }
  }

  return missingSylphDevices.length == 0;
}
