import 'dart:io';
import 'dart:async';
import 'package:meta/meta.dart';

/// Result of running a command.
class ProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final String command;

  ProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.command,
  });

  bool get success => exitCode == 0;
}

/// Run a command and return its result.
Future<ProcessResult> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );

  final stdout = StringBuffer();
  final stderr = StringBuffer();

  final stdoutSub = process.stdout
      .transform(const SystemEncoding().decoder)
      .listen(stdout.write);
  final stderrSub = process.stderr
      .transform(const SystemEncoding().decoder)
      .listen(stderr.write);

  final exitCode = await process.exitCode;
  await Future.wait([stdoutSub.cancel(), stderrSub.cancel()]);

  return ProcessResult(
    exitCode: exitCode,
    stdout: stdout.toString(),
    stderr: stderr.toString(),
    command: '$executable ${arguments.join(' ')}',
  );
}

/// Run a command synchronously and return its result.
@visibleForTesting
ProcessResult runCommandSync(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
}) {
  final result = Process.runSync(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );

  return ProcessResult(
    exitCode: result.exitCode,
    stdout: result.stdout.toString(),
    stderr: result.stderr.toString(),
    command: '$executable ${arguments.join(' ')}',
  );
}
