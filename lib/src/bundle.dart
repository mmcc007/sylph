import 'dart:async';
import 'dart:io';

import 'package:resource/resource.dart';

import 'utils.dart';

// resource consts
const kResourcesUri = 'package:sylph/resources';
const kAppiumTemplateName = 'appium_bundle.zip';
const kAppiumTestSpecName = 'test_spec.yaml';
const kTestBundleDir = 'test_bundle';
const kTestBundleName = '$kTestBundleDir.zip';
const kDefaultFlutterAppName = 'flutter_app';
const kBuildToOsMapFileName = 'build_to_os.txt';

// env consts
const kCIEnvVar = 'CI';
const kExportOptionsPlistEnvVars = ['TEAM_ID'];
const kCIBuildEnvVars = [
  'PUBLISHING_MATCH_CERTIFICATE_REPO',
  'MATCH_PASSWORD',
  'SSH_SERVER',
  'SSH_SERVER_PORT',
  'AWS_ACCESS_KEY_ID',
  'AWS_SECRET_ACCESS_KEY'
];

// substitute names
const kAppIdentifier = 'APP_IDENTIFIER';

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

  final nameVals = {kAppIdentifier: getAppIdentifier()};

  // unpack export options
  await unpackFile('exportOptions.plist', 'ios',
      envVars: kExportOptionsPlistEnvVars, nameVals: nameVals);

  // unpack components used in a CI environment
  final envVars = Platform.environment;
  if (envVars[kCIEnvVar] == 'true') {
    print('CI environment detected. Unpacking related resources.');
    // unpack fastlane
    await unpackFile('fastlane/Appfile', 'ios', nameVals: nameVals);
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

/// Unpack file from resources while optionally applying env vars
/// and/or name/value pairs.
Future unpackFile(String srcPath, String dstDir,
    {List<String> envVars, Map nameVals}) async {
  final resource = Resource('$kResourcesUri/$srcPath');
  String resourceStr = await resource.readAsString();

  // substitute env vars
  if (envVars != null) {
    final env = Platform.environment;
    for (final envVar in envVars) {
      resourceStr = resourceStr.replaceAll('\$$envVar', env[envVar]);
    }
  }

  // substitute name/vals
  if (nameVals != null) {
    for (final name in nameVals.keys) {
      resourceStr = resourceStr.replaceAll('\$$name', nameVals[name]);
    }
  }

  final file = await File('$dstDir/$srcPath').create(recursive: true);
  await file.writeAsString(resourceStr, flush: true);
}

/// Gets the first app identifier found.
String getAppIdentifier() {
  const kIosConfigPath = 'ios/Runner.xcodeproj/project.pbxproj';
  final regExp = 'PRODUCT_BUNDLE_IDENTIFIER = (.*);';
  final iOSConfigStr = File(kIosConfigPath).readAsStringSync();
  final appIdentifier = RegExp(regExp).firstMatch(iOSConfigStr)[1];
  return appIdentifier;
}
