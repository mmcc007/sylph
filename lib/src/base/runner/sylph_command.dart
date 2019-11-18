// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import 'package:quiver/strings.dart';
import 'package:reporting/reporting.dart';
import 'package:tool_base/tool_base.dart';
import '../custom_dimensions.dart';
import '../user_messages.dart';
import 'sylph_command_runner.dart';

enum ExitStatus {
  success,
  warning,
  fail,
}

/// [SylphCommand]s' subclasses' [SylphCommand.runCommand] can optionally
/// provide a [SylphCommandResult] to furnish additional information for
/// analytics.
class SylphCommandResult {
  const SylphCommandResult(
    this.exitStatus, {
    this.timingLabelParts,
    this.endTimeOverride,
  });

  final ExitStatus exitStatus;

  /// Optional data that can be appended to the timing event.
  /// https://developers.google.com/analytics/devguides/collection/analyticsjs/field-reference#timingLabel
  /// Do not add PII.
  final List<String> timingLabelParts;

  /// Optional epoch time when the command's non-interactive wait time is
  /// complete during the command's execution. Use to measure user perceivable
  /// latency without measuring user interaction time.
  ///
  /// [SylphCommand] will automatically measure and report the command's
  /// complete time if not overridden.
  final DateTime endTimeOverride;

  @override
  String toString() {
    switch (exitStatus) {
      case ExitStatus.success:
        return 'success';
      case ExitStatus.warning:
        return 'warning';
      case ExitStatus.fail:
        return 'fail';
      default:
        assert(false);
        return null;
    }
  }
}

abstract class SylphCommand extends Command<void> {
  /// The currently executing command (or sub-command).
  ///
  /// Will be `null` until the top-most command has begun execution.
  static SylphCommand get current => context.get<SylphCommand>();

  @override
  ArgParser get argParser => _argParser;
  final ArgParser _argParser = ArgParser(
    allowTrailingOptions: false,
    usageLineLength:
        outputPreferences.wrapText ? outputPreferences.wrapColumn : null,
  );

  @override
  SylphCommandRunner get runner => super.runner;

  /// The path to send to Google Analytics. Return null here to disable
  /// tracking of the command.
  Future<String> get usagePath async {
    if (parent is SylphCommand) {
      final SylphCommand commandParent = parent;
      final String path = await commandParent.usagePath;
      // Don't report for parents that return null for usagePath.
      return path == null ? null : '$path/$name';
    } else {
      return name;
    }
  }

  /// Additional usage values to be sent with the usage ping.
  Future<Map<String, String>> get usageValues async =>
      const <String, String>{};

  /// Runs this command.
  ///
  /// Rather than overriding this method, subclasses should override
  /// [verifyThenRunCommand] to perform any verification
  /// and [runCommand] to execute the command
  /// so that this method can record and report the overall time to analytics.
  @override
  Future<void> run() {
    final DateTime startTime = systemClock.now();

    return context.run<void>(
      name: 'command',
      overrides: <Type, Generator>{SylphCommand: () => this},
      body: () async {
        if (sylphUsage.isFirstRun) {
          sylphUsage.printWelcome();
        }
        final String commandPath = await usagePath;
        SylphCommandResult commandResult;
        try {
          commandResult = await verifyThenRunCommand(commandPath);
        } on ToolExit {
          commandResult = const SylphCommandResult(ExitStatus.fail);
          rethrow;
        } finally {
          final DateTime endTime = systemClock.now();
          printTrace(userMessages.flutterElapsedTime(
              name, getElapsedAsMilliseconds(endTime.difference(startTime))));
          _sendPostUsage(commandPath, commandResult, startTime, endTime);
        }
      },
    );
  }

  /// Logs data about this command.
  ///
  /// For example, the command path (e.g. `build/apk`) and the result,
  /// as well as the time spent running it.
  void _sendPostUsage(String commandPath, SylphCommandResult commandResult,
      DateTime startTime, DateTime endTime) {
    if (commandPath == null) {
      return;
    }

    // Send command result.
    CommandResultEvent(commandPath, commandResult).send();

    // Send timing.
    final List<String> labels = <String>[
      if (commandResult?.exitStatus != null)
        getEnumName(commandResult.exitStatus),
      if (commandResult?.timingLabelParts?.isNotEmpty ?? false)
        ...commandResult.timingLabelParts,
    ];

    final String label =
        labels.where((String label) => !isBlank(label)).join('-');
    sylphUsage.sendTiming(
      'flutter',
      name,
      // If the command provides its own end time, use it. Otherwise report
      // the duration of the entire execution.
      (commandResult?.endTimeOverride ?? endTime).difference(startTime),
      // Report in the form of `success-[parameter1-parameter2]`, all of which
      // can be null if the command doesn't provide a FlutterCommandResult.
      label: label == '' ? null : label,
    );
  }

  /// Perform validation then call [runCommand] to execute the command.
  /// Return a [Future] that completes with an exit code
  /// indicating whether execution was successful.
  ///
  /// Subclasses should override this method to perform verification
  /// then call this method to execute the command
  /// rather than calling [runCommand] directly.
  @mustCallSuper
  Future<SylphCommandResult> verifyThenRunCommand(String commandPath) async {
    await validateCommand();

    if (commandPath != null) {
      final Map<String, String> additionalUsageValues =
          <String, String>{
        ...?await usageValues,
        CustomDimensions.instance.commandHasTerminal:
//        io.stdout.hasTerminal ? 'true' : 'false',
            stdio.hasTerminal ? 'true' : 'false',
      };
      Usage.command(commandPath, parameters: additionalUsageValues);
    }

    return await runCommand();
  }

  /// Subclasses must implement this to execute the command.
  /// Optionally provide a [SylphCommandResult] to send more details about the
  /// execution for analytics.
  Future<SylphCommandResult> runCommand();

  @protected
  @mustCallSuper
  Future<void> validateCommand() async {}
}

/// An event that reports the result of a top-level command.
class CommandResultEvent extends UsageEvent {
  CommandResultEvent(String commandPath, SylphCommandResult result)
      : super(commandPath, result?.toString() ?? 'unspecified');
}