import 'dart:async';
import 'dart:convert';

import 'package:sylph/sylph.dart';
import 'dart:io';

/// Clears a named directory.
/// Creates directory if none exists.
void clearDirectory(String dir) {
  if (Directory(dir).existsSync()) {
    Directory(dir).deleteSync(recursive: true);
  }
  Directory(dir).createSync(recursive: true);
}

/// Writes a file image to a path on disk.
Future<void> writeFileImage(List<int> fileImage, String path) async {
  final file = await File(path).create(recursive: true);
  await file.writeAsBytes(fileImage, flush: true);
}

/// Executes a command with arguments in a separate process.
/// If [silent] is false, outputs to stdout when command completes.
/// Returns stdout as [String].
String cmd(String cmd, List<String> arguments,
    [String workingDir = '.', bool silent = true]) {
//  print('cmd=\'$cmd ${arguments.join(" ")}\'');
  final result = Process.runSync(cmd, arguments, workingDirectory: workingDir);
  if (!silent) stdout.write(result.stdout);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
  }
  return result.stdout;
}

/// Execute command [cmd] with arguments [arguments] in a separate process
/// and stream stdout/stderr.
Future<void> streamCmd(String cmd, List<String> arguments,
    [ProcessStartMode mode = ProcessStartMode.normal]) async {
//  print('streamCmd=\'$cmd ${arguments.join(" ")}\'');

  final process = await Process.start(cmd, arguments, mode: mode);

  if (mode == ProcessStartMode.normal) {
    final stdoutFuture = process.stdout
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .listen(stdout.writeln)
        .asFuture();
    final stderrFuture = process.stderr
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .listen(stderr.writeln)
        .asFuture();

    await Future.wait([stdoutFuture, stderrFuture]);

    var exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
    }
  }
}

/// Runs a device farm command.
/// Returns as [Map].
Map deviceFarmCmd(List<String> arguments,
    [String workingDir = '.', bool silent = true]) {
  return jsonDecode(
      cmd('aws', ['devicefarm']..addAll(arguments), workingDir, silent));
}

/// Converts [DeviceType] to [String]
String deviceTypeStr(DeviceType deviceType) {
  return DeviceType.ios.toString().split('.')[1];
}

/// Gets device pool from config file.
/// Returns as [Map].
Map getDevicePoolInfo(Map config, String poolName) {
  final List devicePools = config['device_pools'];
//  print('devicePools=$devicePools');
  return devicePools.firstWhere((pool) {
//    print(pool['pool_name']);
    return pool['pool_name'] == poolName;
  }, orElse: () => throw 'Error: device pool $poolName not found');
}

/// Converts [enum] value to [String].
String enumToStr(dynamic _enum) => _enum.toString().split('.').last;
