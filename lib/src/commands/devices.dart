// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:tool_base/tool_base.dart';
import '../base/runner/sylph_command.dart';
import '../device_farm.dart';
import '../base/devices.dart';

class DevicesCommand extends SylphCommand {
  DevicesCommand() {
    argParser.addOption('devices',
        abbr: 'd',
        defaultsTo: 'all',
        help: 'The type of devices.',
        valueHelp: 'all',
        allowed: deviceTypes);
  }

  final List<String> deviceTypes = ['all', 'android', 'ios'];
  @override
  final String name = 'devices';

  @override
  List<String> get aliases => const <String>['dartfmt'];

  @override
  final String description = 'List available devices.';

  @override
  String get invocation => '${runner.executableName} $name <one or more paths>';

  @override
  Future<SylphCommandResult> runCommand() async {
    switch (deviceType) {
      case 'all':
        printDeviceFarmDevices(getDeviceFarmDevices());
        break;
      case 'android':
        printDeviceFarmDevices(getDeviceFarmDevicesByType(DeviceType.android));
        break;
      case 'ios':
        printDeviceFarmDevices(getDeviceFarmDevicesByType(DeviceType.ios));
        break;
    }
    final int result = 0; // always succeeds for now!
    if (result != 0)
      throwToolExit('Listing devices failed: $result', exitCode: result);

    return null;
  }

  String get deviceType {
    if (argResults.wasParsed('devices'))
      return argResults['devices'];
    else if (argResults.rest.isNotEmpty) {
      final String deviceTypeArg = argResults.rest.first;
      final String deviceType =
          deviceTypes.firstWhere((d) => d == deviceTypeArg, orElse: () => null);
      if (deviceType == null)
        throwToolExit(
            '"$deviceTypeArg" is not an allowed value for option "devices".',
            exitCode: 1);
      else
        return deviceType;
    }
    throwToolExit('Unexpected');
    return null;
  }

  void printDeviceFarmDevices(List<DeviceFarmDevice> deviceFarmDevices) {
    for (final deviceFarmDevice in deviceFarmDevices) {
      printStatus(deviceFarmDevice.toString());
    }
    printStatus('${deviceFarmDevices.length} devices');
  }
}
