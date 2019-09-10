//import 'dart:io';

import 'package:sylph/src/base/copy_path.dart';
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
  final appiumTemplatePath = '$stagingDir/$kAppiumTemplateName';
  final testBundleDir = '$stagingDir/$kTestBundleDir';
  final defaultAppDir = '$stagingDir/$kTestBundleDir/$kDefaultFlutterAppName';
  final testBundlePath = '$stagingDir/$kTestBundleName';

  printStatus('Creating test bundle for upload...');

  // unzip template into test bundle dir
  os.unzip(fs.file(appiumTemplatePath), fs.directory(testBundleDir));
//  cmd(['unzip', '-q', appiumTemplatePath, '-d', testBundleDir]);

  // create default app dir in test bundle
//  cmd(['mkdir', defaultAppDir]);
  clearDirectory(defaultAppDir);

  // Copy app dir to test bundle (including any local packages)
  LocalPackageManager.copy(appDir, defaultAppDir, force: true);
  final localPackageManager =
      LocalPackageManager(defaultAppDir, isAppPackage: true);
  localPackageManager.installPackages(appDir);

  // Remove files not used (to reduce zip file size)
//  cmd(['rm', '-rf', '$defaultAppDir/build']);
//  cmd(['rm', '-rf', '$defaultAppDir/ios/Flutter/Flutter.framework']);
//  cmd(['rm', '-rf', '$defaultAppDir/ios/Flutter/App.framework']);
  deleteDir('$defaultAppDir/build');
  deleteDir('$defaultAppDir/ios/Flutter/Flutter.framework');
  deleteDir('$defaultAppDir/ios/Flutter/App.framework');

  // Copy scripts to test bundle
//  cmd(['cp', '-r', '$stagingDir/script', defaultAppDir]);
  copyPathSync('$stagingDir/script', '$defaultAppDir/script');

  // Copy build-to-os-map file to test bundle
//  cmd(['cp', '$stagingDir/$kBuildToOsMapFileName', defaultAppDir]);
  copyFile('$stagingDir/$kBuildToOsMapFileName', defaultAppDir);

  // Zip test bundle
//  cmd(['zip', '-rq', testBundlePath, testBundleDir]); // works fine on mac!
  if (platform.isWindows) {
    // tried using windows built-in compression but did not work
    // eg, powershell Compress-Archive -Path Z:\tmp\sylph\test_bundle -DestinationPath Z:\tmp\test_bundle_windows.zip
    cmd(['7z', 'a', testBundlePath, '$testBundleDir/*']);
  } else {
    os.zip(fs.directory(testBundleDir), fs.file(testBundlePath));
  }

  // report size of bundle
//  final size =
//      (int.parse(cmd(['stat', '-f%z', testBundlePath])) / 1024 / 1024).round();
  final size = getSizeAsMB(fs.file(testBundlePath).lengthSync());
  printStatus('Test bundle created (size $size)');

  return size;
}
