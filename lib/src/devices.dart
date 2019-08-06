import 'package:version/version.dart';

import 'utils.dart';

enum DeviceType { ios, android }

Iterable getDevices(DeviceType deviceType) {
  return getSylphDevices().where((device) => device.deviceType == deviceType);
}

List getSylphDevices() {
  final devices = deviceFarmCmd(['list-devices'])['devices'];
  final sylphDevices = [];
  for (final device in devices) {
    sylphDevices.add(SylphDevice(
        device['name'],
        device['modelId'],
        Version.parse(device['os']),
        device['platform'] == 'ANDROID' ? DeviceType.android : DeviceType.ios));
  }
  sylphDevices.sort();
  return sylphDevices;
}

class SylphDevice implements Comparable {
  SylphDevice(this.name, this.model, this.os, this.deviceType);
  final String name, model;
  final Version os;
  final DeviceType deviceType;

  @override
  String toString() {
    return 'name:$name, model:$model, os:$os, deviceType:${enumToStr(deviceType)}';
  }

  @override
  int compareTo(other) {
    final nameCompare = name.compareTo(other.name);
    if (nameCompare != 0) {
      return nameCompare;
    } else {
      final modelCompare = model.compareTo(other.model);
      if (modelCompare != 0) {
        return modelCompare;
      } else {
        return os == other.os ? 0 : os > other.os ? 1 : -1;
      }
    }
  }
}
