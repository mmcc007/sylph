import 'package:collection/collection.dart';

import 'utils.dart';

isValidSylphDevices(Map config) {
  final fixMemberOrder = (Map dev) =>
      {'name': dev['name'], 'model': dev['model'], 'os': dev['os']};
  final allSylphDevices = [];
  // iterate the pools
  for (final pool in config['device_pools']) {
    // iterate the pool's devices
    for (final sylphDevice in pool['devices']) {
      allSylphDevices.add(fixMemberOrder(sylphDevice));
    }
  }

  // get all job devices
  final allJobDevices = deviceFarmCmd(['list-devices'])['devices'];

  // find all matching sylph devices
  final matchingSylphDevices = [];
  final missingSylphDevices = [];
  for (final sylphDevice in allSylphDevices) {
    Map jobDevice = allJobDevices.firstWhere(
        (jobDevice) =>
            MapEquality().equals(getSylphDevice(jobDevice), sylphDevice),
        orElse: () => null);
    if (jobDevice != null) {
      matchingSylphDevices.add(getSylphDevice(jobDevice));
    } else {
      print('no match found for $sylphDevice');
      missingSylphDevices.add(sylphDevice);
    }
  }

//  expect(matchingSylphDevices, allSylphDevices);

  return missingSylphDevices.length == 0;
}
