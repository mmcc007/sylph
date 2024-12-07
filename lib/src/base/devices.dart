import 'package:version/version.dart';

import 'utils.dart';

enum DeviceType { ios, android }

/// Load a sylph device from [Map] of device and pool type.
SylphDevice loadSylphDevice(Map<String, dynamic> device, String poolType) {
  return SylphDevice(
    device['name'] as String,
    device['model'] as String,
    Version.parse(device['os'].toString()),
    stringToEnum(DeviceType.values, poolType),
  );
}

const kOrderEqual = 0;

/// Describe a sylph device that can be compared and sorted.
class SylphDevice implements Comparable<SylphDevice> {
  SylphDevice(this.name, this.model, this.os, this.deviceType);

  final String name;
  final String model;
  final Version os;
  final DeviceType deviceType;

  @override
  String toString() {
    return 'name:$name, model:$model, os:$os, deviceType:${enumToStr(deviceType)}';
  }

  @override
  int compareTo(SylphDevice other) {
    final nameCompare = name.compareTo(other.name);
    if (nameCompare != kOrderEqual) {
      return nameCompare;
    }
    final modelCompare = model.compareTo(other.model);
    if (modelCompare != kOrderEqual) {
      return modelCompare;
    }
    final osCompare = os == other.os ? kOrderEqual : os.compareTo(other.os);
    if (osCompare != kOrderEqual) {
      return osCompare;
    }
    return enumToStr(deviceType).compareTo(enumToStr(other.deviceType));
  }

  @override
  bool operator ==(Object other) {
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

enum FormFactor { phone, tablet }

/// Describe a device farm device that can be compared and sorted.
/// Also can be compared with a [SylphDevice].
class DeviceFarmDevice extends SylphDevice {
  DeviceFarmDevice(
    String name,
    String modelId,
    Version os,
    DeviceType deviceType,
    this.formFactor,
    this.availability,
    this.arn,
  ) : super(name, modelId, os, deviceType);

  final FormFactor formFactor;
  final String availability;
  final String arn;

  @override
  String toString() {
    // do not show arn for now
    return '${super.toString()}, formFactor:${enumToStr(formFactor)}, availability:$availability';
  }

  @override
  int compareTo(SylphDevice other) {
    if (other is DeviceFarmDevice) {
      final formFactorCompare =
          enumToStr(formFactor).compareTo(enumToStr(other.formFactor));
      if (formFactorCompare != kOrderEqual) {
        return formFactorCompare;
      }
    }
    final sylphCompare = super.compareTo(other);
    if (sylphCompare != kOrderEqual) {
      return sylphCompare;
    }
    return kOrderEqual;
  }

  @override
  bool operator ==(Object other) {
    if (other is DeviceFarmDevice) {
      return super == other &&
          other.formFactor == formFactor &&
          other.availability == availability &&
          other.arn == arn;
    }
    if (other is SylphDevice) {
      // allow comparison with a sylph device
      return super == other;
    }
    return false;
  }

  @override
  int get hashCode =>
      super.hashCode ^
      formFactor.hashCode ^
      availability.hashCode ^
      arn.hashCode;
}
