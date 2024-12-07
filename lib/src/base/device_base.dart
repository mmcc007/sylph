import 'package:meta/meta.dart';

/// Base class for device information.
@immutable
class DeviceBase {
  final String name;
  final String model;
  final String os;
  final String osVersion;
  final String arn;

  const DeviceBase({
    required this.name,
    required this.model,
    required this.os,
    required this.osVersion,
    required this.arn,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceBase &&
        other.name == name &&
        other.model == model &&
        other.os == os &&
        other.osVersion == osVersion &&
        other.arn == arn;
  }

  @override
  int get hashCode => Object.hash(name, model, os, osVersion, arn);

  @override
  String toString() =>
      'Device(name: $name, model: $model, os: $os, version: $osVersion)';
}

/// Device pool configuration.
@immutable
class DevicePool {
  final String name;
  final List<DeviceBase> devices;

  const DevicePool({
    required this.name,
    required this.devices,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DevicePool &&
        other.name == name &&
        _listEquals(other.devices, devices);
  }

  @override
  int get hashCode => Object.hash(name, devices);

  @override
  String toString() => 'DevicePool(name: $name, devices: $devices)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
