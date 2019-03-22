import 'dart:async';
import 'dart:convert';

import 'package:sylph/sylph.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:resource/resource.dart';

/// Clears a named directory.
/// Creates directory if none exists.
void clearDirectory(String dir) {
  if (Directory(dir).existsSync()) {
    Directory(dir).deleteSync(recursive: true);
  }
  Directory(dir).createSync(recursive: true);
}

/// Reads a named file image from resources.
/// Returns the file image.
Future<List<int>> readResourceImage(String fileImageName) async {
  final resource = Resource('$kResourcesUri/$fileImageName');
  return resource.readAsBytes();
}

/// Writes a file image to a path.
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
  }, orElse: () => null);
}

/// Unpacks resources found in package into [tmpDir].
/// Appium template is used to deliver tests.
/// Scripts are used to initialize device and run tests.
Future<void> unpackResources(String tmpDir) async {
  final testBundlePath = '$tmpDir/$kTestBundle';

  // unpack Appium template
  await writeFileImage(
      await readResourceImage(kAppiumTemplate), testBundlePath);

  // unpack scripts
  final appPath = Directory.current.path;
//  print('appPath=$appPath');
  final appName = p.basename(appPath);
  await unpackScripts('$tmpDir/$appName');
}

/// Read scripts from resources and install in staging area.
Future<void> unpackScripts(String dstDir) async {
  await unpackScript(
    'test_android.sh',
    '$dstDir/script',
  );
  await unpackScript(
    'test_ios.sh',
    '$dstDir/script',
  );
}

/// Read script from resources and install in staging area.
Future<void> unpackScript(String srcPath, String dstDir) async {
  final resource = Resource('$kResourcesUri/$srcPath');
  final String script = await resource.readAsString();
  final file = await File('$dstDir/$srcPath').create(recursive: true);
  await file.writeAsString(script, flush: true);
  // make executable
  cmd('chmod', ['u+x', '$dstDir/$srcPath']);
}

/// Converts enum value to [String].
String enumToStr(dynamic _enum) => _enum.toString().split('.').last;
