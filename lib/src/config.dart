import 'package:sylph/src/utils.dart';

import 'devices.dart';

/// default config file name
const String kConfigFileName = 'sylph.yaml';

class Config {
  Config({this.configPath = kConfigFileName, String configStr}) {
    if (configStr != null) {
      _configInfo = parseYamlStr(configStr);
    } else {
      _configInfo = parseYamlFile(configPath);
    }
  }

  final String configPath;
  Map<String, dynamic> _configInfo;

  // Getters
//  List<SylphDevice> get devices =>
//      _processDevices(_configInfo['devices'], isFrameEnabled);
//  List<SylphDevice> get iosDevices =>
//      devices.where((device) => device.deviceType == DeviceType.ios).toList();
//  List<SylphDevice> get androidDevices => devices
//      .where((device) => device.deviceType == DeviceType.android)
//      .toList();

//  SylphDevice getDevice(String deviceName) => devices.firstWhere(
//          (device) => device.name == deviceName,
//      orElse: () => throw 'Error: no device configured for \'$deviceName\'');

  List<SylphDevice> getPoolDevices(String poolName) =>
      _getSylphDevices(_getPoolInfo(poolName));

  _getPoolInfo(String poolName) {
    final poolInfo = _configInfo['device_pools'].firstWhere(
        (devicePool) => devicePool['pool_name'] == poolName,
        orElse: () => null);
    return poolInfo;
  }

  /// Get current sylph devices from [Map] of device pool info.
  List<SylphDevice> _getSylphDevices(Map devicePoolInfo) {
    final _sylphDevices = devicePoolInfo['devices'];
    final sylphDevices = <SylphDevice>[];
    for (final _sylphDevice in _sylphDevices) {
      sylphDevices
          .add(loadSylphDevice(_sylphDevice, devicePoolInfo['pool_type']));
    }
    sylphDevices.sort();
    return sylphDevices;
  }

  /// Check for active pool type.
  /// Active pools can only be one of [DeviceType].
  bool isPoolTypeActive(DeviceType poolType) => _isPoolTypeActive(poolType);

  bool _isPoolTypeActive(DeviceType poolType) {
    // get active pool names
    List poolNames = [];
    for (final testSuite in _configInfo['test_suites']) {
      for (var poolName in testSuite['pool_names']) {
        poolNames.add(poolName);
      }
    }
    poolNames = poolNames.toSet().toList(); // remove dups

    // get active pool types
    List poolTypes = [];
    for (final poolName in poolNames) {
      poolTypes.add(stringToEnum(
          DeviceType.values,
          getDevicePoolInfo(
              _configInfo['device_pools'], poolName)['pool_type']));
    }

    // test for requested pool type
    return poolTypes.contains(poolType);
  }

  DeviceType getPoolType(String poolName) =>
      stringToEnum(DeviceType.values, _getPoolInfo(poolName)['pool_type']);
}

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
