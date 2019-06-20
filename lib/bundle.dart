import 'dart:async';
import 'dart:io';

import 'package:resource/resource.dart';
import 'package:sylph/utils.dart';

const kResourcesUri = 'package:sylph/resources';
const kAppiumTemplateName = 'appium_bundle.zip';
const kTestBundleDir = 'test_bundle';
const kTestBundleName = '$kTestBundleDir.zip';
const kDefaultFlutterAppName = 'flutter_app';
const kBuildToOsMapFileName = 'build_to_os.txt';

/// Bundles Flutter tests using appium template found in staging area.
/// Resulting bundle is saved on disk in temporary location
/// for later upload.
Future<void> bundleFlutterTests(Map config) async {
  final stagingDir = config['tmp_dir'];
  final appiumTemplatePath = '$stagingDir/$kAppiumTemplateName';
  final testBundleDir = '$stagingDir/$kTestBundleDir';
  final defaultAppDir = '$testBundleDir/$kDefaultFlutterAppName';
  final testBundlePath = '$stagingDir/$kTestBundleName';

  print('Creating test bundle for upload...');

  // create fresh staging area
  await unpackResources(stagingDir); // again

  // unzip template into test bundle dir
  cmd('unzip', ['-q', appiumTemplatePath, '-d', testBundleDir], '.', false);

  // create default app dir in test bundle
  cmd('mkdir', [defaultAppDir], '.', false);

  // clean build dir in case a build is present
  cmd('flutter', ['clean'], '.', true);

  // update .packages in case last build was on a different flutter repo
  cmd('flutter', ['packages', 'get'], '.', true);

  // Copy app dir to test bundle
  cmd('cp', ['-r', '.', defaultAppDir], '.', false);

  // Copy scripts to test bundle
  cmd('cp', ['-r', 'script', defaultAppDir], stagingDir, false);

  // Copy build to os map file to test bundle
  cmd('cp', [kBuildToOsMapFileName, defaultAppDir], stagingDir, false);

  // Remove files not used (to reduce zip file size)
  cmd('rm', ['-rf', '$defaultAppDir/ios/Flutter/Flutter.framework'], '.',
      false);
  cmd('rm', ['-rf', '$defaultAppDir/ios/Flutter/App.framework'], '.', false);

  // Zip test bundle
  cmd('zip', ['-rq', '../$kTestBundleName', '.'], testBundleDir, false);

  // report size of bundle
  final size = (int.parse(cmd('stat', ['-f%z', testBundlePath], '.', true)) /
          1024 /
          1024)
      .round();
  print('Test bundle created (size $size MB)');
}

/// Unpacks resources found in package into [tmpDir].
/// Appium template is used to deliver tests.
/// Scripts are used to initialize device and run tests.
Future<void> unpackResources(String tmpDir) async {
  clearDirectory(tmpDir);

  // unpack Appium template
  await writeFileImage(await readResourceImage(kAppiumTemplateName),
      '$tmpDir/$kAppiumTemplateName');

  // unpack scripts
  await unpackScripts(tmpDir);

  // unpack build to os map file
  await unpackFile(kBuildToOsMapFileName, tmpDir);
}

/// Reads a named file image from resources.
/// Returns the file image as [List].
Future<List<int>> readResourceImage(String fileImageName) async {
  final resource = Resource('$kResourcesUri/$fileImageName');
  return resource.readAsBytes();
}

/// Read scripts from resources and install in staging area.
Future<void> unpackScripts(String dstDir) async {
  await unpackScript(
    'script/test_android.sh',
    '$dstDir',
  );
  await unpackScript(
    'script/test_ios.sh',
    '$dstDir',
  );
  await unpackScript(
    'script/local_utils.sh',
    '$dstDir',
  );
}

/// Read script from resources and install in staging area.
Future<void> unpackScript(String srcPath, String dstDir) async {
  await unpackFile(srcPath, dstDir);
  // make executable
  cmd('chmod', ['u+x', '$dstDir/$srcPath']);
}

Future unpackFile(String srcPath, String dstDir) async {
  final resource = Resource('$kResourcesUri/$srcPath');
  final String script = await resource.readAsString();
  final file = await File('$dstDir/$srcPath').create(recursive: true);
  await file.writeAsString(script, flush: true);
}
