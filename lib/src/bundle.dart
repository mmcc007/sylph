import 'dart:async';
import 'dart:io';

import 'package:resource/resource.dart';

import 'utils.dart';

const kResourcesUri = 'package:sylph/resources';
const kAppiumTemplateName = 'appium_bundle.zip';
const kAppiumTestSpecName = 'test_spec.yaml';
const kTestBundleDir = 'test_bundle';
const kTestBundleName = '$kTestBundleDir.zip';
const kDefaultFlutterAppName = 'flutter_app';
const kBuildToOsMapFileName = 'build_to_os.txt';

/// Bundles Flutter tests using appium template found in staging area.
/// Resulting bundle is saved on disk in temporary location
/// for later upload.
Future<int> bundleFlutterTests(Map config) async {
  final stagingDir = config['tmp_dir'];
  final appiumTemplatePath = '$stagingDir/$kAppiumTemplateName';
  final testBundleDir = '$stagingDir/$kTestBundleDir';
  final defaultAppDir = '$testBundleDir/$kDefaultFlutterAppName';
  final testBundlePath = '$stagingDir/$kTestBundleName';

  print('Creating test bundle for upload...');

  // unzip template into test bundle dir
  cmd('unzip', ['-q', appiumTemplatePath, '-d', testBundleDir], '.', false);

  // create default app dir in test bundle
  cmd('mkdir', [defaultAppDir], '.', false);

  // Copy app dir to test bundle
  cmd('cp', ['-r', '.', defaultAppDir], '.', false);

  // update .packages in case last build was on a different flutter repo
  cmd('flutter', ['packages', 'get'], defaultAppDir, true);

  // clean build dir in case a build is present
  cmd('flutter', ['clean'], defaultAppDir, true);

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

  return size;
}

/// Unpacks resources found in package into [tmpDir].
/// Appium template is used to deliver tests.
/// Scripts are used to initialize device and run tests.
Future<void> unpackResources(String tmpDir) async {
  print('Unpacking sylph resources to $tmpDir');
  clearDirectory(tmpDir);

  // unpack Appium template
  await writeFileImage(await readResourceImage(kAppiumTemplateName),
      '$tmpDir/$kAppiumTemplateName');

  // unpack Appium test spec
  await unpackFile(kAppiumTestSpecName, tmpDir);

  // unpack scripts
  await unpackScripts(tmpDir);

  // unpack build to os map file
  await unpackFile(kBuildToOsMapFileName, tmpDir);

  // unpack export options
  // todo: configure exportOptions.plist for provisioning profile, team, etc...
  await unpackFile('exportOptions.plist', 'ios');

  // unpack components used in a CI environment
  final envVars = Platform.environment;
  if (envVars['CI'] == 'true') {
    print('CI environment detected. Unpacking related resources');
    // unpack fastlane
    await unpackFile('fastlane/Appfile', 'ios');
    await unpackFile('fastlane/Fastfile', 'ios');
    await unpackFile('GemFile', 'ios');
    await unpackFile('GemFile.lock', 'ios');

    // unpack dummy keys
    await unpackFile('dummy-ssh-keys/key', '.');
    await unpackFile('dummy-ssh-keys/key.pub', '.');
  }
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
