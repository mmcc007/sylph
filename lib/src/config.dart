import 'package:collection/collection.dart' show ListEquality;
import 'base/utils.dart' show parseYamlStr, parseYamlFile, stringToEnum;
import 'package:tool_base/tool_base.dart' show printError;

import 'base/devices.dart';

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
  int get sylphTimeout => _configInfo['sylph_timeout'];
  String get projectName => _configInfo['project_name'];
  int get defaultJobTimeout => _configInfo['default_job_timeout'];
  String get tmpDir => _configInfo['tmp_dir'];
  bool get concurrentRuns => _configInfo['concurrent_runs'];
  String get artifactsDir => _configInfo['artifacts_dir'];
  String get flavor => _configInfo['flavor'];

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
          _getDevicePoolInfo(
              _configInfo['device_pools'], poolName)['pool_type']));
    }

    // test for requested pool type
    return poolTypes.contains(poolType);
  }

  /// Gets device pool from config file.
  /// Returns as [Map].
  Map _getDevicePoolInfo(List devicePools, String poolName) {
    return devicePools.firstWhere((pool) => pool['pool_name'] == poolName,
        orElse: () => throw 'Error: device pool $poolName not found');
  }

  DeviceType getPoolType(String poolName) =>
      stringToEnum(DeviceType.values, _getPoolInfo(poolName)['pool_type']);

  List<TestSuite> get testSuites {
    final List<TestSuite> testSuites = [];
    _configInfo['test_suites'].forEach((testSuite) {
      testSuites.add(TestSuite(
          testSuite['test_suite'],
          testSuite['main'],
          _processList(testSuite['tests']),
          _processList(testSuite['pool_names']),
          testSuite['job_timeout']));
    });
    return testSuites;
  }

  List<SylphDevice> getDevicesInSuite(String suiteName) =>
      __devicesInSuite(suiteName);

  List<SylphDevice> __devicesInSuite(String suiteName) {
    List poolNames = [];
    for (final testSuite in testSuites) {
      for (final poolName in testSuite.poolNames) {
        poolNames.add(poolName);
      }
    }
    poolNames = poolNames.toSet().toList(); // remove duplicates

    final List<SylphDevice> devicesInSuite = [];

    for (final pool in _configInfo['device_pools']) {
      if (poolNames.contains(pool['pool_name'])) {
        // iterate the pool's devices
        for (final sylphDevice in pool['devices']) {
          devicesInSuite.add(loadSylphDevice(sylphDevice, pool['pool_type']));
        }
      }
    }
    return devicesInSuite;
  }

  /// Check that pool types are valid.
  bool isValidPoolTypes() {
    bool isInValidPoolType = false;
    for (final devicePool in _configInfo['device_pools']) {
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

  DevicePool getDevicePool(String poolName) {
    final poolInfo = _getPoolInfo(poolName);
    return DevicePool(
        poolInfo['pool_name'],
        stringToEnum(DeviceType.values, poolInfo['pool_type']),
        _getSylphDevices(poolInfo));
  }

  List<String> _processList(List list) {
    return list.map((item) {
      return item.toString();
    }).toList();
  }
}

/// Describe a test suite
class TestSuite {
  final String name, main;
  final List<String> tests;
  final List<String> poolNames;
  final int jobTimeout;

  TestSuite(this.name, this.main, this.tests, this.poolNames, this.jobTimeout);

  @override
  bool operator ==(other) {
    return other is TestSuite &&
        other.name == name &&
        other.main == main &&
        eq(other.tests, tests) &&
        eq(other.poolNames, poolNames) &&
        other.jobTimeout == jobTimeout;
  }

  @override
  String toString() =>
      'name: $name, main: $main, tests: $tests, poolNames: $poolNames, jobTimeout: $jobTimeout';
}

/// Describe a device pool
class DevicePool {
  final String name;
  final DeviceType deviceType;
  final List<SylphDevice> devices;

  DevicePool(this.name, this.deviceType, this.devices);
}

Function eq = const ListEquality().equals;
