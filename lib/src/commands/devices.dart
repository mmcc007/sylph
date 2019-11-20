// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:tool_base/tool_base.dart';

import '../base/devices.dart';
import '../base/runner/sylph_command.dart';
import '../device_farm.dart';

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
  final String description = 'List available devices in cloud.';

  @override
  String get invocation =>
      '${runner.executableName} $name <[<all|ios|android>]';

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
      default:
        throwToolExit(
            '"${argResults.rest.first}" is not a permitted option for command "devices".',
            exitCode: 1);
    }
    // todo: return error code
    return null;
  }

  String get deviceType {
    if (argResults.wasParsed('devices'))
      return argResults['devices'];
    else if (argResults.rest.isNotEmpty) {
      return deviceTypes.firstWhere((d) => d == argResults.rest.first, orElse: () => null);
    } else
      return deviceTypes.first; // default to 'all'
  }

  void printDeviceFarmDevices(List<DeviceFarmDevice> deviceFarmDevices) {
    for (final deviceFarmDevice in deviceFarmDevices) {
      printStatus(deviceFarmDevice.toString());
    }
    printStatus('${deviceFarmDevices.length} devices');
  }
}
