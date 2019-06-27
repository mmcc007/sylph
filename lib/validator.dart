import 'package:collection/collection.dart';
import 'package:test/test.dart';

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

  // convert matching job devices to sylph devices
//  final matchingSylphDevices =
//      matchingJobDevices.map((jobDevice) => getSylphDevice(jobDevice)).toList();
//  print(
//      'allSylphDevices=$allSylphDevices, matchingSylphDevices=$matchingSylphDevices');

  // confirm both are equal
//  Function deepEq = const DeepCollectionEquality().equals;
////  final allSylphDevicesFound = deepEq(allSylphDevices, matchingSylphDevices);
//  Function unOrdDeepEq = const DeepCollectionEquality.unordered().equals;
//  final allSylphDevicesFound =
//      unOrdDeepEq(allSylphDevices, matchingSylphDevices);
//
//  // report missing devices if not all found
//  final mapEq = const MapEquality().equals;
//  if (!allSylphDevicesFound) {
//    // sort both lists
////    allSylphDevices.sort(sortSylphDevices);
////    matchingSylphDevices.sort(sortSylphDevices);
//    for (final sylphDevice in allSylphDevices) {
//      // search for sylph device in matching devices
//      bool matchFound = false;
//      for (final matchingDevice in matchingSylphDevices) {
//        if (mapEq(sylphDevice, matchingDevice)) {
//          matchFound = true;
//        }
//      }
//      if (!matchFound) print('Device not found: $sylphDevice');
//    }
//  }
  expect(matchingSylphDevices, allSylphDevices);

  return missingSylphDevices.length == 0;
}
