//import 'dart:io';

import 'package:sylph/src/config.dart';
import 'package:sylph/src/resources.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'base/local_packages.dart';
import 'base/utils.dart';

const kDefaultFlutterAppName = 'flutter_app';

/// Bundles Flutter tests using appium template found in staging area.
/// Resulting bundle is saved on disk in temporary location
/// for later upload.
int bundleFlutterTests(Config config, {String appDir = '.'}) {
  final stagingDir = config.tmpDir;
  final appiumTemplatePath = '$stagingDir/$kAppiumTemplateName';
  final testBundleDir = '$stagingDir/$kTestBundleDir';
  final defaultAppDir = '$stagingDir/$kTestBundleDir/$kDefaultFlutterAppName';
  final testBundlePath = '$stagingDir/$kTestBundleName';

  printStatus('Creating test bundle for upload...');

  // unzip template into test bundle dir
  cmd(['unzip', '-q', appiumTemplatePath, '-d', testBundleDir]);

  // create default app dir in test bundle
  cmd(['mkdir', defaultAppDir]);
  clearDirectory(defaultAppDir);

  // Copy app dir to test bundle (including any local packages)
  LocalPackageManager.copy(appDir, defaultAppDir, force: true);
  final localPackageManager =
      LocalPackageManager(defaultAppDir, isAppPackage: true);
  localPackageManager.installPackages(appDir);

  // Remove files not used (to reduce zip file size)
  cmd(['rm', '-rf', '$defaultAppDir/build']);
  cmd(['rm', '-rf', '$defaultAppDir/ios/Flutter/Flutter.framework']);
  cmd(['rm', '-rf', '$defaultAppDir/ios/Flutter/App.framework']);

  // Copy scripts to test bundle
  cmd(['cp', '-r', '$stagingDir/script', defaultAppDir]);

  // Copy build-to-os-map file to test bundle
  cmd(['cp', '$stagingDir/$kBuildToOsMapFileName', defaultAppDir]);

  // Zip test bundle
  cmd(['zip', '-rq', testBundlePath, testBundleDir]);

  // report size of bundle
  final size =
      (int.parse(cmd(['stat', '-f%z', testBundlePath])) / 1024 / 1024).round();
  printStatus('Test bundle created (size $size MB)');

  return size;
}
