// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:tool_base/tool_base.dart';
import '../base/reporting/reporting.dart';
import '../sylph_run.dart';
import '../base/runner/sylph_command.dart';

//abstract class RunCommandBase extends FlutterCommand with DeviceBasedDevelopmentArtifacts {
abstract class RunCommandBase extends SylphCommand {
  // Used by run and drive commands.
  RunCommandBase({bool verboseHelp = false}) {
    argParser
      ..addFlag(
        'trace-startup',
        negatable: false,
        help:
            'Trace application startup, then exit, saving the trace to a file.',
      )
      ..addFlag(
        'verbose-system-logs',
        negatable: false,
        help: 'Include verbose logging from the flutter engine.',
      )
      ..addOption(
        'route',
        help: 'Which route to load when running the app.',
      );
  }

  bool get traceStartup => argResults['trace-startup'];

  String get route => argResults['route'];
}

class RunCommand extends RunCommandBase {
  RunCommand({bool verboseHelp = false}) : super(verboseHelp: verboseHelp) {
    argParser
      ..addOption(configArg,
          abbr: 'c',
          defaultsTo: 'sylph.yaml',
          help: 'Path to config file.',
          valueHelp: 'sylph.yaml');
  }
  final configArg = 'config';

  @override
  final String name = 'run';

  @override
  final String description = 'Run your Flutter app on an attached device.';

  @override
  Future<Map<CustomDimensions, String>> get usageValues async {
    String deviceType, deviceOsVersion;
    bool isEmulator;

    final List<String> hostLanguage = <String>[];

    return <CustomDimensions, String>{
      CustomDimensions.commandRunIsEmulator: '$isEmulator',
      CustomDimensions.commandRunTargetName: deviceType,
      CustomDimensions.commandRunTargetOsVersion: deviceOsVersion,
//      CustomDimensions.commandRunModeName: modeName,
//      CustomDimensions.commandRunProjectModule:
//          '${FlutterProject.current().isModule}',
      CustomDimensions.commandRunProjectHostLanguage: hostLanguage.join(','),
    };
  }

  @override
  Future<SylphCommandResult> runCommand() async {
    DateTime appStartedTime;
    // Sync completer so the completing agent attaching to the resident doesn't
    // need to know about analytics.
    //
    // Do not add more operations to the future.
    final Completer<void> appStartedTimeRecorder = Completer<void>.sync();
    // This callback can't throw.
    unawaited(appStartedTimeRecorder.future.then<void>((_) {
      appStartedTime = systemClock.now();
    }));

//    final int result = await runner.run(
//      appStartedCompleter: appStartedTimeRecorder,
//      route: route,
//    );

    // validate args
    final configFilePath = argResults[configArg];
    final file = fs.file(configFilePath);
    if (!await file.exists()) {
      throwToolExit('File "${file.path}" does not exist.', exitCode: 1);
    }

    final timestamp = sylphTimestamp();
    final sylphRunName = 'sylph run $timestamp';
    printStatus('Starting Sylph run \'$sylphRunName\' on AWS Device Farm ...');
    printStatus('Config file: $configFilePath');

    final sylphRunSucceeded = await sylphRun(
        configFilePath, sylphRunName, timestamp, flags['verbose']);
    printStatus(
        'Sylph run completed in ${sylphRuntimeFormatted(timestamp, DateTime.now())}.');
//    await Usage.instance.ensureAnalyticsSent();
    int result;
    if (sylphRunSucceeded) {
      printStatus('Sylph run \'$sylphRunName\' succeeded.');
      result = 0;
    } else {
      printStatus('Sylph run \'$sylphRunName\' failed.');
      result = 1;
    }

    appStartedTimeRecorder?.complete(); //add this to command on completion

    if (result != 0) {
      throwToolExit(null, exitCode: result);
    }
    return SylphCommandResult(
      ExitStatus.success,
      timingLabelParts: <String>[
//        hotMode ? 'hot' : 'cold',
//        getModeName(getBuildMode()),
//        devices.length == 1
//            ? getNameForTargetPlatform(await devices[0].targetPlatform)
//            : 'multiple',
//        devices.length == 1 && await devices[0].isLocalEmulator
//            ? 'emulator'
//            : null,
      ],
      endTimeOverride: appStartedTime,
    );
  }
}
