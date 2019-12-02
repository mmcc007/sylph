// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:sylph/src/commands/run.dart';

import 'runner.dart' as runner;

import 'src/base/runner/sylph_command.dart';
import 'src/commands/config.dart';
import 'src/commands/devices.dart';

/// Main entry point for commands.
///
/// This function is intended to be used from the `sylph` command line tool.
Future<void> main(List<String> args) async {
  final bool verbose = args.contains('-v') || args.contains('--verbose');

  final bool help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final bool muteCommandLogging = help;
  final bool verboseHelp = help && verbose;

  await runner.run(
    args,
    <SylphCommand>[
      ConfigCommand(verboseHelp: verboseHelp),
      DevicesCommand(),
      RunCommand(verboseHelp: verboseHelp),
    ],
    verbose: verbose,
    muteCommandLogging: muteCommandLogging,
    verboseHelp: verboseHelp,
//     overrides: <Type, Generator>{
//       // The build runner instance is not supported in google3 because
//       // the build runner packages are not synced internally.
//       CodeGenerator: () => const BuildRunner(),
//       WebCompilationProxy: () => BuildRunnerWebCompilationProxy(),
//       // The web runner is not supported internally because it depends
//       // on dwds.
//       WebRunnerFactory: () => DwdsWebRunnerFactory(),
//     }
  );
}
