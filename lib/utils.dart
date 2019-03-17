import 'dart:async';

import 'package:sylph/sylph.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:resource/resource.dart';

/// Clear directory [dir].
/// Create directory if none exists.
void clearDirectory(String dir) {
  if (Directory(dir).existsSync()) {
    Directory(dir).deleteSync(recursive: true);
  }
  Directory(dir).createSync(recursive: true);
}

/// Read a file image from resources.
Future<List<int>> readResourceImage(String fileImageName) async {
  final resource = Resource('$resourcesUri/$fileImageName');
  return resource.readAsBytes();
}

/// Write a file image.
Future<void> writeFileImage(List<int> fileImage, String path) async {
  final file = await File(path).create(recursive: true);
  await file.writeAsBytes(fileImage, flush: true);
}

/// Execute command [cmd] with arguments [arguments] in a separate process and return stdout.
///
/// If [silent] is false, output to stdout.
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

/// Converts [DeviceType] to [String]
String deviceTypeStr(DeviceType deviceType) {
  return DeviceType.ios.toString().split('.')[1];
}

/// Gets device pool from config file.
Map getDevicePoolInfo(Map config, String poolName) {
  final List devicePools = config['device_pools'];
//  print('devicePools=$devicePools');
  return devicePools.firstWhere((pool) {
//    print(pool['pool_name']);
    return pool['pool_name'] == poolName;
  }, orElse: () => null);
}

Future unpackResources(String tmpDir) async {
  final testBundlePath = '$tmpDir/$testBundle';

  // unpack Appium template
  await writeFileImage(await readResourceImage(appiumTemplate), testBundlePath);

  // unpack scripts
  final appPath = Directory.current.path;
  print('appPath=$appPath');
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
Future unpackScript(String srcPath, String dstDir) async {
  final resource = Resource('$resourcesUri/$srcPath');
  final String script = await resource.readAsString();
  final file = await File('$dstDir/$srcPath').create(recursive: true);
  await file.writeAsString(script, flush: true);
  // make executable
  cmd('chmod', ['u+x', '$dstDir/$srcPath']);
}

// Converts enum value to string
String enumToStr(dynamic _enum) => _enum.toString().split('.').last;
