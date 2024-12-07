import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:meta/meta.dart';
import 'logging.dart';

/// A utility class for reading and validating YAML configuration files.
class ConfigFile {
  final String path;
  final Map<String, dynamic> _config;

  ConfigFile._(this.path, this._config);

  /// Load a configuration file from the given path.
  static ConfigFile load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Configuration file not found', path);
    }

    final contents = file.readAsStringSync();
    final yaml = loadYaml(contents) as YamlMap;
    return ConfigFile._(path, _convertYamlToMap(yaml));
  }

  /// Get a value from the configuration.
  T? getValue<T>(String key, {T? defaultValue}) {
    final value = _config[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is! T) {
      printError(
        'Invalid type for configuration key "$key". '
        'Expected ${T.toString()}, got ${value.runtimeType}',
      );
      return defaultValue;
    }
    return value as T;
  }

  /// Get a required value from the configuration.
  T getRequiredValue<T>(String key) {
    final value = getValue<T>(key);
    if (value == null) {
      throw StateError('Required configuration key "$key" not found in $path');
    }
    return value;
  }

  /// Get a nested configuration value.
  T? getNested<T>(List<String> keys, {T? defaultValue}) {
    dynamic current = _config;
    for (final key in keys) {
      if (current is! Map<String, dynamic>) {
        return defaultValue;
      }
      current = current[key];
      if (current == null) {
        return defaultValue;
      }
    }
    if (current is! T) {
      printError(
        'Invalid type for configuration key "${keys.join('.')}". '
        'Expected ${T.toString()}, got ${current.runtimeType}',
      );
      return defaultValue;
    }
    return current as T;
  }

  /// Get a required nested configuration value.
  T getRequiredNested<T>(List<String> keys) {
    final value = getNested<T>(keys);
    if (value == null) {
      throw StateError(
        'Required configuration key "${keys.join('.')}" not found in $path',
      );
    }
    return value;
  }

  /// Convert a YamlMap to a regular Map<String, dynamic>.
  static Map<String, dynamic> _convertYamlToMap(YamlMap yaml) {
    final result = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is YamlMap) {
        result[key] = _convertYamlToMap(value);
      } else if (value is YamlList) {
        result[key] = _convertYamlToList(value);
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  /// Convert a YamlList to a regular List<dynamic>.
  static List<dynamic> _convertYamlToList(YamlList yaml) {
    return yaml.map((item) {
      if (item is YamlMap) {
        return _convertYamlToMap(item);
      } else if (item is YamlList) {
        return _convertYamlToList(item);
      } else {
        return item;
      }
    }).toList();
  }
}
