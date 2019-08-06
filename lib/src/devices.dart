import 'package:version/version.dart';

import 'utils.dart';

enum DeviceType { ios, android }

List<DeviceFarmDevice> getDevices(DeviceType deviceType) {
  return getDeviceFarmDevices()
      .where((device) => device.deviceType == deviceType)
      .toList();
}

List<DeviceFarmDevice> getDeviceFarmDevices() {
  final _deviceFarmDevices = deviceFarmCmd(['list-devices'])['devices'];
  final List<DeviceFarmDevice> deviceFarmDevices = [];
  for (final _deviceFarmDevice in _deviceFarmDevices) {
    deviceFarmDevices.add(getDeviceFarmDevice(_deviceFarmDevice));
  }
  deviceFarmDevices.sort();
  return deviceFarmDevices;
}

SylphDevice getDeviceFarmDevice(Map device) {
  return DeviceFarmDevice(
      device['name'],
      device['modelId'],
      Version.parse(device['os']),
      device['platform'] == 'ANDROID' ? DeviceType.android : DeviceType.ios,
      device['availability'],
      device['arn']);
}

List getSylphDevices(Map devicePoolInfo) {
  final _sylphDevices = devicePoolInfo['devices'];
  final sylphDevices = [];
  for (final _sylphDevice in _sylphDevices) {
    sylphDevices.add(getSylphDevice(_sylphDevice, devicePoolInfo['pool_type']));
  }
  sylphDevices.sort();
  return sylphDevices;
}

SylphDevice getSylphDevice(Map device, String poolType) {
  return SylphDevice(
      device['name'],
      device['model'],
      Version.parse(device['os'].toString()),
      stringToEnum(DeviceType.values, poolType));
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

  @override
  bool operator ==(other) {
    return other is SylphDevice &&
        other.name == name &&
        other.model == model &&
        other.os == os &&
        other.deviceType == deviceType;
  }

  @override
  int get hashCode =>
      name.hashCode ^ model.hashCode ^ os.hashCode ^ deviceType.hashCode;
}

class DeviceFarmDevice extends SylphDevice {
  DeviceFarmDevice(String name, String modelId, Version os,
      DeviceType deviceType, this.availability, this.arn)
      : super(name, modelId, os, deviceType);

  final String availability, arn;

  @override
  String toString() {
    return '${super.toString()}, availability: $availability';
  }

  @override
  bool operator ==(other) {
    if (other is SylphDevice) {
      return super == (other);
    } else {
      return other is DeviceFarmDevice &&
          super == (other) &&
          other.availability == availability &&
          other.arn == arn;
    }
  }

  @override
  int get hashCode => super.hashCode ^ availability.hashCode ^ arn.hashCode;
}
