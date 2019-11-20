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
String bundleFlutterTests(Config config, {String appDir = '.'}) {
  final stagingDir = config.tmpDir;
  final appiumTemplateZip = '$stagingDir/$kAppiumTemplateZip';
  final testBundleDir = '$stagingDir/$kTestBundleDir';
  final defaultAppDir = '$stagingDir/$kTestBundleDir/$kDefaultFlutterAppName';
  final testBundleZip = '$stagingDir/$kTestBundleZip';

  printStatus('Creating test bundle for upload...');

  // unzip template into test bundle dir
  unzip(appiumTemplateZip, testBundleDir);

  // create default app dir in test bundle
  createDir(defaultAppDir);

  // Copy app dir to test bundle (including any local packages)
  LocalPackageManager.copy(appDir, defaultAppDir, force: true);
  final localPackageManager =
      LocalPackageManager(defaultAppDir, isAppPackage: true);
  localPackageManager.installPackages(appDir);

  // Remove files not used (to reduce zip file size)
  deleteDir('$defaultAppDir/build');
  deleteDir('$defaultAppDir/ios/Flutter/Flutter.framework');
  deleteDir('$defaultAppDir/ios/Flutter/App.framework');

  // Copy scripts to test bundle
  copyDir('$stagingDir/script', '$defaultAppDir/script');

  // Copy build-to-os-map file to test bundle
  copyFile('$stagingDir/$kBuildToOsMapFileName', defaultAppDir);

  // zip test bundle
  zip(testBundleDir, testBundleZip);

  final size = getSizeAsMB(fs.file(testBundleZip).lengthSync());
  printStatus('Test bundle created (size $size)');

  return size;
}
