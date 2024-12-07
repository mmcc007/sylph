import 'package:version/version.dart';

import 'utils.dart';

enum DeviceType { ios, android }

/// Load a sylph device from [Map] of device and pool type.
SylphDevice loadSylphDevice(Map device, String poolType) {
  return SylphDevice(
      device['name'],
      device['model'],
      Version.parse(device['os'].toString()),
      stringToEnum(DeviceType.values, poolType));
}

const kOrderEqual = 0;

/// Describe a sylph device that can be compared and sorted.
class SylphDevice implements Comparable {
  SylphDevice(this.name, this.model, this.os, this.deviceType)
      : assert(name != null),
        assert(model != null),
        assert(os != null),
        assert(deviceType != null);

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
    if (nameCompare != kOrderEqual) {
      return nameCompare;
    } else {
      final modelCompare = model.compareTo(other.model);
      if (modelCompare != kOrderEqual) {
        return modelCompare;
      } else {
        // Version does not implement compareTo
        final osCompare = os == other.os ? kOrderEqual : os > other.os ? 1 : -1;
        if (osCompare != kOrderEqual) {
          return osCompare;
        } else {
          return enumToStr(deviceType).compareTo(enumToStr(other.deviceType));
        }
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

enum FormFactor { phone, tablet }

/// Describe a device farm device that can be compared and sorted.
/// Also can be compared with a [SylphDevice].
class DeviceFarmDevice extends SylphDevice {
  DeviceFarmDevice(String name, String modelId, Version os,
      DeviceType deviceType, this.formFactor, this.availability, this.arn)
      : assert(formFactor != null),
        assert(availability != null),
        assert(arn != null),
        super(name, modelId, os, deviceType);

  final FormFactor formFactor;
  final String availability, arn;

  @override
  String toString() {
    // do not show arn for now
    return '${super.toString()}, formFactor:${enumToStr(formFactor)}, availability:$availability';
  }

  @override
  int compareTo(other) {
    final formFactorCompare =
        enumToStr(formFactor).compareTo(enumToStr(other.formFactor));
    if (formFactorCompare != kOrderEqual) {
      return formFactorCompare;
    } else {
      final sylphCompare = super.compareTo(other);
      if (sylphCompare != kOrderEqual) {
        return sylphCompare;
      } else {
        return kOrderEqual;
      }
    }
  }

  @override
  bool operator ==(other) {
    if (other is DeviceFarmDevice) {
      return super == other &&
          other.formFactor == formFactor &&
          other.availability == availability &&
          other.arn == arn;
    } else {
      if (other is SylphDevice) {
        // allow comparison with a sylph device
        return super == other;
      } else {
        // any other type
        return false;
      }
    }
  }

  @override
  int get hashCode =>
      super.hashCode ^
      formFactor.hashCode ^
      availability.hashCode ^
      arn.hashCode;
}
