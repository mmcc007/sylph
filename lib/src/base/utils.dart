//import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:tool_base/tool_base.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

/// Parses a named yaml file.
/// Returns as [Map].
Map parseYamlFile(String yamlPath) =>
    jsonDecode(jsonEncode(loadYaml(fs.file(yamlPath).readAsStringSync())));

/// Parse a yaml string.
/// Returns as [Map].
Map parseYamlStr(String yamlString) =>
    jsonDecode(jsonEncode(loadYaml(yamlString)));

/// Clears a named directory.
/// Creates directory if none exists.
void clearDirectory(String dir) {
  if (fs.directory(dir).existsSync()) {
    fs.directory(dir).deleteSync(recursive: true);
  }
  fs.directory(dir).createSync(recursive: true);
}

///// Deletes file at [filePath].
//void deleteFile(String filePath, {bool force = false}) {
//  printTrace('deleting file $filePath');
//  final file = fs.file(filePath);
//  if (file.existsSync()) {
//    if ((file is Directory)) throw '$filePath is not a file';
//    printStatus('deleting $filePath');
//    file.deleteSync();
//  } else {
//    if (!force) throw 'file $filePath does not exist';
//  }
//}
//
///// Moves file from [srcPath] to [dstPath].
///// Existing files are over-written, if any.
//void moveFile(String srcPath, String dstPath) {
//  final file = fs.file(srcPath);
//  file.copySync(dstPath);
//  file.deleteSync();
//}

/// Copies file from [srcPath] to [dstDir].
/// Existing file is over-written, if any.
void copyFile(String srcPath, String dstDir) {
  fs.file(srcPath).copySync('$dstDir/${p.basename(srcPath)}');
}

/// Recursively copies `srcDir` to `destDir`.
///
/// Creates `destDir` if needed.
void copyDir(String srcDir, String destDir) {
  copyDirectorySync(fs.directory(srcDir), fs.directory(destDir));
}

/// Creates a directory at [dirPath].
///
/// Creates path recursively if necessary.
void createDir(String dirPath) {
  fs.directory(dirPath).createSync(recursive: true);
}

/// Deletes directory at [dirPath] if it exists.
void deleteDir(String dirPath) {
  if (fs.directory(dirPath).existsSync()) {
    fs.directory(dirPath).deleteSync(recursive: true);
  }
}

void zip(String from, String to) {
//  printTrace('zipping from $from to $to');
  if (platform.isWindows) {
    // os.zip() does not work on windows (device farm re
    // tried using windows built-in compression but did not work
    // eg, powershell Compress-Archive -Path Z:\tmp\sylph\test_bundle -DestinationPath Z:\tmp\test_bundle_windows.zip
    cmd(['7z', 'a', to, '$from/*']);
  } else {
    os.zip(fs.directory(from), fs.file(to));
  }
}

void unzip(String from, String to) {
//  printTrace('unzipping from $from to $to');
//  cmd(['unzip', '-q', from, '-d', to]);
  os.unzip(fs.file(from), fs.directory(to));
//  runSync(<String>['unzip', '-o', '-q', from, '-d', to]);
}

/// Writes a file image to a path on disk.
Future<void> writeFileImage(List<int> fileImage, String path) async {
  final File file = await fs.file(path).create(recursive: true);
  await file.writeAsBytes(fileImage, flush: true);
}

/// Executes a command with arguments in a separate process.
/// If [silent] is false, outputs to stdout when command completes.
/// Returns stdout as [String].
String cmd(List<String> cmd,
    {String workingDirectory = '.', bool silent = true}) {
  final result = processManager.runSync(cmd,
      workingDirectory: workingDirectory, runInShell: false);
  traceCommand(cmd, workingDirectory: workingDirectory);
  if (!silent) printStatus(result.stdout);
  if (result.exitCode != 0) {
    printError(result.stderr);
    throw 'command failed: exitcode=${result.exitCode}, cmd=\'${cmd.join(" ")}\', workingDir=$workingDirectory';
  }
  return result.stdout;
}

/// Execute command [cmd] with arguments [arguments] in a separate process
/// and stream stdout/stderr.
Future<void> streamCmd(
  List<String> cmd, {
  String workingDirectory = '.',
  ProcessStartMode mode = ProcessStartMode.normal,
}) async {
  if (mode == ProcessStartMode.normal) {
    int exitCode = await runCommandAndStreamOutput(cmd,
        workingDirectory: workingDirectory);
    if (exitCode != 0 && mode == ProcessStartMode.normal) {
      throw 'command failed: exitcode=$exitCode, cmd=\'${cmd.join(" ")}\', workingDirectory=$workingDirectory, mode=$mode';
    }
  } else {
//    final process = await runDetached(cmd);
//    exitCode = await process.exitCode;
    unawaited(runDetached(cmd));
  }
}

/// Trace a command.
void traceCommand(List<String> args, {String workingDirectory}) {
  final String argsText = args.join(' ');
  if (workingDirectory == null) {
    printTrace('executing: $argsText');
  } else {
    printTrace('executing: [$workingDirectory${fs.path.separator}] $argsText');
  }
}

/// Runs a device farm command.
/// Returns as [Map].
Map deviceFarmCmd(List<String> arguments, [String workingDir = '.']) {
  return jsonDecode(cmd(['aws', 'devicefarm']..addAll(arguments),
      workingDirectory: workingDir));
}

/// Converts [enum] value to [String].
String enumToStr(dynamic _enum) => _enum.toString().split('.').last;

/// Converts [String] to [enum].
T stringToEnum<T>(List<T> values, String value) {
  return values.firstWhere((type) => enumToStr(type) == value,
      orElse: () =>
          throw 'Fatal: \'$value\' not found in ${values.toString()}');
}

/// generates a download directory path for each Device Farm run's artifacts
String runArtifactsDirPath(String downloadDirPrefix, String sylphRunName,
    String projectName, String poolName) {
  final downloadDir = '$downloadDirPrefix/' +
      '${sylphRunName.replaceAll(':', '_')}/$projectName/$poolName'
          .replaceAll(' ', '_');
  return downloadDir;
}

/// Formats a list of ARNs for Device Farm API
/// Returns a formatted [String]
String formatArns(List arns) {
  String formatted = '';
  for (final arn in arns) {
    formatted += '\\"$arn\\",';
  }
  // remove last char
  return formatted.substring(0, formatted.length - 1);
}

/// tests for empty [string].
bool isEmpty(String string) => !(string != null && string.isNotEmpty);
