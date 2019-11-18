// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:completion/completion.dart';
import 'package:file/file.dart';
import 'package:process/process.dart';
import 'package:reporting/reporting.dart';
import 'package:tool_base/tool_base.dart';

import '../user_messages.dart';

class SylphCommandRunner extends CommandRunner<void> {
  SylphCommandRunner({bool verboseHelp = false})
      : super(
          'sylph',
          'Runs Flutter integration tests on real devices in cloud.\n'
              '\n'
              'Common commands:\n'
              '\n'
              '  sylph devices [options]\n'
              '    Get a list of currently available devices.\n'
              '\n'
              '  sylph run [options]\n'
              '    Run your Flutter application integration tests on pools of devices in cloud.',
        ) {
    argParser.addFlag('verbose',
        abbr: 'v',
        negatable: false,
        help: 'Noisy logging, including all shell commands executed.\n'
            'If used with --help, shows hidden options.');
    argParser.addFlag('quiet',
        negatable: false,
        hide: !verboseHelp,
        help: 'Reduce the amount of output from some commands.');
    argParser.addFlag('wrap',
        negatable: true,
        hide: !verboseHelp,
        help:
            'Toggles output word wrapping, regardless of whether or not the output is a terminal.',
        defaultsTo: true);
    argParser.addOption('wrap-column',
        hide: !verboseHelp,
        help:
            'Sets the output wrap column. If not set, uses the width of the terminal. No '
            'wrapping occurs if not writing to a terminal. Use --no-wrap to turn off wrapping '
            'when connected to a terminal.',
        defaultsTo: null);
    argParser.addFlag('version',
        negatable: false, help: 'Reports the version of this tool.');
    argParser.addFlag('color',
        negatable: true,
        hide: !verboseHelp,
        help:
            'Whether to use terminal colors (requires support for ANSI escape sequences).',
        defaultsTo: true);
    argParser.addFlag('version-check',
        negatable: true,
        defaultsTo: true,
        hide: !verboseHelp,
        help: 'Allow Sylph to check for updates when this command runs.');
    argParser.addFlag('suppress-analytics',
        negatable: false,
        help: 'Suppress analytics reporting when this command runs.');
    argParser.addFlag('bug-report',
        negatable: false,
        help: 'Captures a bug report file to submit to the Sylph team.\n'
            'Contains local paths, device identifiers, and log snippets.');

    argParser.addOption('record-to',
        hide: !verboseHelp,
        help:
            'Enables recording of process invocations (including stdout and stderr of all such invocations), '
            'and file system access (reads and writes).\n'
            'Serializes that recording to a directory with the path specified in this flag. If the '
            'directory does not already exist, it will be created.');
    argParser.addOption('replay-from',
        hide: !verboseHelp,
        help:
            'Enables mocking of process invocations by replaying their stdout, stderr, and exit code from '
            'the specified recording (obtained via --record-to). The path specified in this flag must refer '
            'to a directory that holds serialized process invocations structured according to the output of '
            '--record-to.');
  }

  @override
  ArgParser get argParser => _argParser;
  final ArgParser _argParser = ArgParser(
    allowTrailingOptions: false,
    usageLineLength:
        outputPreferences.wrapText ? outputPreferences.wrapColumn : null,
  );

  @override
  String get usageFooter {
    return wrapText('Run "sylph help -v" for verbose help output.');
  }

  @override
  String get usage {
    final String usageWithoutDescription =
        super.usage.substring(description.length + 2);
    return '${wrapText(description)}\n\n$usageWithoutDescription';
  }

  @override
  ArgResults parse(Iterable<String> args) {
    try {
      // This is where the CommandRunner would call argParser.parse(args). We
      // override this function so we can call tryArgsCompletion instead, so the
      // completion package can interrogate the argParser, and as part of that,
      // it calls argParser.parse(args) itself and returns the result.
      return tryArgsCompletion(args, argParser);
    } on ArgParserException catch (error) {
      if (error.commands.isEmpty) {
        usageException(error.message);
      }

      Command<void> command = commands[error.commands.first];
      for (String commandName in error.commands.skip(1)) {
        command = command.subcommands[commandName];
      }

      command.usageException(error.message);
      return null;
    }
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    final Map<Type, dynamic> contextOverrides = <Type, dynamic>{
      Flags: Flags(topLevelResults),
    };

    // Check for verbose.
    if (topLevelResults['verbose']) {
      // Override the logger.
      contextOverrides[Logger] = VerboseLogger(logger);
    }

    // Don't set wrapColumns unless the user said to: if it's set, then all
    // wrapping will occur at this width explicitly, and won't adapt if the
    // terminal size changes during a run.
    int wrapColumn;
    if (topLevelResults.wasParsed('wrap-column')) {
      try {
        wrapColumn = int.parse(topLevelResults['wrap-column']);
        if (wrapColumn < 0) {
          throwToolExit(userMessages
              .runnerWrapColumnInvalid(topLevelResults['wrap-column']));
        }
      } on FormatException {
        throwToolExit(userMessages
            .runnerWrapColumnParseError(topLevelResults['wrap-column']));
      }
    }

    // If we're not writing to a terminal with a defined width, then don't wrap
    // anything, unless the user explicitly said to.
    final bool useWrapping = topLevelResults.wasParsed('wrap')
        ? topLevelResults['wrap']
//        : io.stdio.terminalColumns == null ? false : topLevelResults['wrap'];
        : stdio.terminalColumns == null ? false : topLevelResults['wrap'];
    contextOverrides[OutputPreferences] = OutputPreferences(
      wrapText: useWrapping,
      showColor: topLevelResults['color'],
      wrapColumn: wrapColumn,
    );

    String recordTo = topLevelResults['record-to'];
    String replayFrom = topLevelResults['replay-from'];

    if (topLevelResults['bug-report']) {
      // --bug-report implies --record-to=<tmp_path>
      final Directory tempDir = const LocalFileSystem()
          .systemTempDirectory
          .createTempSync('sylph_tools_bug_report.');
      recordTo = tempDir.path;

      // Record the arguments that were used to invoke this runner.
      final File manifest = tempDir.childFile('MANIFEST.txt');
      final StringBuffer buffer = StringBuffer()
        ..writeln('# arguments')
        ..writeln(topLevelResults.arguments)
        ..writeln()
        ..writeln('# rest')
        ..writeln(topLevelResults.rest);
      await manifest.writeAsString(buffer.toString(), flush: true);

      // ZIP the recording up once the recording has been serialized.
      addShutdownHook(() async {
        final File zipFile =
            getUniqueFile(fs.currentDirectory, 'bugreport', 'zip');
        os.zip(tempDir, zipFile);
        printStatus(userMessages.runnerBugReportFinished(zipFile.basename));
      }, ShutdownStage.POST_PROCESS_RECORDING);
      addShutdownHook(
          () => tempDir.delete(recursive: true), ShutdownStage.CLEANUP);
    }

    assert(recordTo == null || replayFrom == null);

    if (recordTo != null) {
      recordTo = recordTo.trim();
      if (recordTo.isEmpty) throwToolExit(userMessages.runnerNoRecordTo);
      contextOverrides.addAll(<Type, dynamic>{
        ProcessManager: getRecordingProcessManager(recordTo),
        FileSystem: getRecordingFileSystem(recordTo),
        Platform: await getRecordingPlatform(recordTo),
      });
//      VMService.enableRecordingConnection(recordTo);
    }

    if (replayFrom != null) {
      replayFrom = replayFrom.trim();
      if (replayFrom.isEmpty) throwToolExit(userMessages.runnerNoReplayFrom);
      contextOverrides.addAll(<Type, dynamic>{
        ProcessManager: await getReplayProcessManager(replayFrom),
        FileSystem: getReplayFileSystem(replayFrom),
        Platform: await getReplayPlatform(replayFrom),
      });
//      VMService.enableReplayConnection(replayFrom);
    }

    await context.run<void>(
      overrides:
          contextOverrides.map<Type, Generator>((Type type, dynamic value) {
        return MapEntry<Type, Generator>(type, () => value);
      }),
      body: () async {
        logger.quiet = topLevelResults['quiet'];

        if (topLevelResults['suppress-analytics'])
          sylphUsage.suppressAnalytics = true;

//        if (topLevelResults['version']) {
//          flutterUsage.sendCommand('version');
//          String status;
//          if (topLevelResults['machine']) {
//            status = const JsonEncoder.withIndent('  ')
//                .convert(FlutterVersion.instance.toJson());
//          } else {
//            status = FlutterVersion.instance.toString();
//          }
//          printStatus(status);
//          return;
//        }

        await super.runCommand(topLevelResults);
      },
    );
  }
}
