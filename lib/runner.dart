// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl_standalone.dart' as intl_standalone;
import 'package:meta/meta.dart';
import 'package:reporting/reporting.dart';
import 'package:tool_base/tool_base.dart';

import 'src/base/runner/sylph_command.dart';
import 'src/base/runner/sylph_command_runner.dart';
import 'src/context_runner.dart';

const kAnalyticsUA = 'UA-150933570-1';
const kSettings = 'sylph';
const kProductId = 'Sylph';
const String kCrashServerHost = 'clients2.mauricemccabe.com';
const String kCrashEndpointPath = '/cr/report';
final File configFile=fs.file('${platform.environment['HOME']}/.$kSettings');

CrashReportSender _crashReportSender;

CrashReportSender get crashReportSender {
  if (_crashReportSender == null)
    _crashReportSender = CrashReportSender(
        http.Client(), kCrashServerHost, kCrashEndpointPath, kProductId);
  return _crashReportSender;
}

@visibleForTesting
set crashReportSender(CrashReportSender crashReportSender) =>
    _crashReportSender = crashReportSender;

/// Runs the Sylph tool with support for the specified list of [commands].
Future<int> run(
  List<String> args,
  List<SylphCommand> commands, {
  bool muteCommandLogging = false,
  bool verbose = false,
  bool verboseHelp = false,
  bool reportCrashes,
  String sylphVersion,
  Map<Type, Generator> overrides,
}) {
  reportCrashes ??= !isRunningOnBot;

  if (muteCommandLogging) {
// Remove the verbose option; for help and doctor, users don't need to see
// verbose logs.
    args = List<String>.from(args);
    args.removeWhere(
        (String option) => option == '-v' || option == '--verbose');
  }

  final SylphCommandRunner runner =
      SylphCommandRunner(verboseHelp: verboseHelp);
  commands.forEach(runner.addCommand);

  return runInContext<int>(() async {
    // Initialize the system locale.
    final String systemLocale = await intl_standalone.findSystemLocale();
    intl.Intl.defaultLocale = intl.Intl.verifiedLocale(
      systemLocale,
      intl.NumberFormat.localeExists,
      onFailure: (String _) => 'en_US',
    );

//    String getVersion() => flutterVersion ?? FlutterVersion.instance.getVersionString(redactUnknownBranches: true);
    String getVersion() => sylphVersion ?? '0.6.0';
    Object firstError;
    StackTrace firstStackTrace;
    return await runZoned<Future<int>>(() async {
      try {
        await runner.run(args);
        return await _exit(0);
      } catch (error, stackTrace) {
        firstError = error;
        firstStackTrace = stackTrace;
        return await _handleToolError(
            error, stackTrace, verbose, args, reportCrashes, getVersion);
      }
    }, onError: (Object error, StackTrace stackTrace) async {
// If sending a crash report throws an error into the zone, we don't want
// to re-try sending the crash report with *that* error. Rather, we want
// to send the original error that triggered the crash report.
      final Object e = firstError ?? error;
      final StackTrace s = firstStackTrace ?? stackTrace;

      await _handleToolError(e, s, verbose, args, reportCrashes, getVersion);
    });
  }, overrides: overrides);
}

Future<int> _handleToolError(
  dynamic error,
  StackTrace stackTrace,
  bool verbose,
  List<String> args,
  bool reportCrashes,
  String getSylphVersion(),
) async {
  if (error is UsageException) {
    printError('${error.message}\n');
    printError(
        "Run 'sylph -h' (or 'sylph <command> -h') for available sylph commands and options.");
    // Argument error exit code.
    return _exit(64);
  } else if (error is ToolExit) {
    if (error.message != null) printError(error.message);
    if (verbose) printError('\n$stackTrace\n');
    return _exit(error.exitCode ?? 1);
  } else if (error is ProcessExit) {
    // We've caught an exit code.
    if (error.immediate) {
      exit(error.exitCode);
      return error.exitCode;
    } else {
      return _exit(error.exitCode);
    }
  } else {
    // We've crashed; emit a log report.
    stderr.writeln();

    if (!reportCrashes) {
      // Print the stack trace on the bots - don't write a crash report.
      stderr.writeln('$error');
      stderr.writeln(stackTrace.toString());
      return _exit(1);
    } else {
      // Report to both [Usage] and [CrashReportSender].
      sylphUsage.sendException(error);
      await crashReportSender.sendReport(
        error: error,
        stackTrace: stackTrace,
        getFlutterVersion: getSylphVersion,
        command: args.join(' '),
      );

      if (error is String)
        stderr.writeln('Oops; sylph has exited unexpectedly: "$error".');
      else
        stderr.writeln('Oops; sylph has exited unexpectedly.');

      try {
        final File file =
            await _createLocalCrashReport(args, error, stackTrace);
        stderr.writeln(
          'Crash report written to ${file.path};\n'
          'please let us know at https://github.com/mmcc007/sylph/issues.',
        );
        return _exit(1);
      } catch (error) {
        stderr.writeln(
          'Unable to generate crash report due to secondary error: $error\n'
          'please let us know at https://github.com/mmcc007/sylph/issues.',
        );
        // Any exception throw here (including one thrown by `_exit()`) will
        // get caught by our zone's `onError` handler. In order to avoid an
        // infinite error loop, we throw an error that is recognized above
        // and will trigger an immediate exit.
        throw ProcessExit(1, immediate: true);
      }
    }
  }
}

/// File system used by the crash reporting logic.
///
/// We do not want to use the file system stored in the context because it may
/// be recording. Additionally, in the case of a crash we do not trust the
/// integrity of the [AppContext].
@visibleForTesting
FileSystem crashFileSystem = const LocalFileSystem();

/// Saves the crash report to a local file.
Future<File> _createLocalCrashReport(
    List<String> args, dynamic error, StackTrace stackTrace) async {
  File crashFile =
      getUniqueFile(crashFileSystem.currentDirectory, 'sylph', 'log');

  final StringBuffer buffer = StringBuffer();

  buffer.writeln(
      'Sylph crash report; please file at https://github.com/mmcc007/sylph/issues.\n');

  buffer.writeln('## command\n');
  buffer.writeln('sylph ${args.join(' ')}\n');

  buffer.writeln('## exception\n');
  buffer.writeln('${error.runtimeType}: $error\n');
  buffer.writeln('```\n$stackTrace```\n');

  try {
    await crashFile.writeAsString(buffer.toString());
  } on FileSystemException catch (_) {
    // Fallback to the system temporary directory.
    crashFile =
        getUniqueFile(crashFileSystem.systemTempDirectory, 'sylph', 'log');
    try {
      await crashFile.writeAsString(buffer.toString());
    } on FileSystemException catch (e) {
      printError('Could not write crash report to disk: $e');
      printError(buffer.toString());
    }
  }

  return crashFile;
}

Future<int> _exit(int code) async {
  if (sylphUsage.isFirstRun) sylphUsage.printWelcome();

  // Send any last analytics calls that are in progress without overly delaying
  // the tool's exit (we wait a maximum of 250ms).
  if (sylphUsage.enabled) {
    final Stopwatch stopwatch = Stopwatch()..start();
    await sylphUsage.ensureAnalyticsSent();
    printTrace('ensureAnalyticsSent: ${stopwatch.elapsedMilliseconds}ms');
  }

  // Run shutdown hooks before flushing logs
  await runShutdownHooks();

  final Completer<void> completer = Completer<void>();

  // Give the task / timer queue one cycle through before we hard exit.
  Timer.run(() {
    try {
      printTrace('exiting with code $code');
      exit(code);
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  });

  await completer.future;
  return code;
}
