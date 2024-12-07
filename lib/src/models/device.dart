/// Represents a device in AWS Device Farm.
class Device {
  Device({
    required this.name,
    required this.model,
    required this.os,
    required this.osVersion,
    required this.arn,
  });

  final String name;
  final String model;
  final String os;
  final String osVersion;
  final String arn;

  @override
  String toString() {
    return 'Device{name: $name, model: $model, os: $os, osVersion: $osVersion}';
  }
}

/// Represents a device pool in AWS Device Farm.
class DevicePool {
  DevicePool({
    required this.name,
    required this.devices,
  });

  final String name;
  final List<Device> devices;

  @override
  String toString() {
    return 'DevicePool{name: $name, devices: $devices}';
  }
}
