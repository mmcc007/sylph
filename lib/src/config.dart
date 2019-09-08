import 'package:sylph/src/utils.dart';

import 'devices.dart';

/// Check for active pool type.
/// Active pools can only be one of [DeviceType].
bool isPoolTypeActive(Map config, DeviceType poolType) {
  // get active pool names
  List poolNames = [];
  for (final testSuite in config['test_suites']) {
    for (var poolName in testSuite['pool_names']) {
      poolNames.add(poolName);
    }
  }
  poolNames = poolNames.toSet().toList(); // remove dups

  // get active pool types
  List poolTypes = [];
  for (final poolName in poolNames) {
    poolTypes.add(stringToEnum(DeviceType.values,
        getDevicePoolInfo(config['device_pools'], poolName)['pool_type']));
  }

  // test for requested pool type
  return poolTypes.contains(poolType);
}
