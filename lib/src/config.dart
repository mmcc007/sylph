import 'dart:io';

import 'package:yaml/yaml.dart';
import 'utils/tool_base.dart' show printError;

const String kConfigFileName = 'sylph.yaml';

/// Configuration for running tests.
class Config {
  String configPath;
  YamlMap? config;

  Config({this.configPath = kConfigFileName, required String configStr}) {
    try {
      config = loadYaml(configStr) as YamlMap;
    } catch (e) {
      printError('Error parsing config file: $e');
      exit(1);
    }
  }

  /// Returns the project name from the config.
  String? get projectName => config?['project_name'] as String?;

  /// Returns the default job timeout from the config.
  int? get defaultJobTimeout => config?['default_job_timeout'] as int?;

  /// Returns the device pools from the config.
  List<YamlMap>? get devicePools {
    final pools = config?['device_pools'];
    if (pools == null) return null;
    return (pools as YamlList).map((pool) => pool as YamlMap).toList();
  }

  /// Returns the test suites from the config.
  List<YamlMap>? get testSuites {
    final suites = config?['test_suites'];
    if (suites == null) return null;
    return (suites as YamlList).map((suite) => suite as YamlMap).toList();
  }
}
