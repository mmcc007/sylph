import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';

/// A call to a process, used for verifying process calls.
class ProcessCall {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  ProcessCall(this.executable, this.arguments, [this.workingDirectory]);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is ProcessCall &&
        executable == other.executable &&
        _listEquals(arguments, other.arguments) &&
        workingDirectory == other.workingDirectory;
  }

  @override
  int get hashCode => Object.hash(executable, arguments, workingDirectory);

  @override
  String toString() {
    final workingDir = workingDirectory == null ? '' : ' in $workingDirectory';
    return '$executable ${arguments.join(' ')}$workingDir';
  }
}

/// A fake process manager that records process calls and can provide fake responses.
class FakeProcessManager implements ProcessManager {
  final List<ProcessCall> _processCallLog = <ProcessCall>[];
  final Map<ProcessCall, ProcessResult> _fakeResults = {};
  final List<ProcessResult> _fakeResultQueue = [];

  /// The list of process calls made.
  List<ProcessCall> get processCallLog => List<ProcessCall>.from(_processCallLog);

  /// Add a fake result that will be returned when a matching process call is made.
  void addFakeResult(ProcessCall call, ProcessResult result) {
    _fakeResults[call] = result;
  }

  /// Add a fake result to a queue that will be returned in order for any process call.
  void addFakeResultForAnyCall(ProcessResult result) {
    _fakeResultQueue.add(result);
  }

  @override
  Future<ProcessResult> run(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    final call = ProcessCall(
      command[0].toString(),
      command.skip(1).map((arg) => arg.toString()).toList(),
      workingDirectory,
    );
    _processCallLog.add(call);

    if (_fakeResultQueue.isNotEmpty) {
      return _fakeResultQueue.removeAt(0);
    }

    final result = _fakeResults[call];
    if (result == null) {
      throw ProcessException(
        command[0].toString(),
        command.skip(1).map((arg) => arg.toString()).toList(),
        'No fake result specified for process call',
      );
    }
    return result;
  }

  @override
  ProcessResult runSync(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) {
    throw UnimplementedError('runSync is not implemented');
  }

  @override
  Future<Process> start(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    throw UnimplementedError('start is not implemented');
  }

  @override
  bool canRun(Object executable, {String? workingDirectory}) => true;

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
