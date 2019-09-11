import 'dart:async';

import 'package:resource/resource.dart';
import 'base/utils.dart';
import 'package:tool_base/tool_base.dart';

// resource consts
const kResourcesUri = 'package:sylph/resources';
const kAppiumTemplateZip = 'appium_bundle.zip';
const kAppiumTestSpecName = 'test_spec.yaml';
const kTestBundleDir = 'test_bundle';
const kTestBundleZip = '$kTestBundleDir.zip';
const kBuildToOsMapFileName = 'build_to_os.txt';

// env vars
const kCIEnvVar = 'CI'; // detects if running in CI
const kExportOptionsPlistEnvVars = [
  // required for iOS build locally and in CI
  'TEAM_ID'
];
const kIosCIBuildEnvVars = [
  // required for iOS build in CI
  'PUBLISHING_MATCH_CERTIFICATE_REPO',
  'MATCH_PASSWORD',
  'SSH_SERVER',
  'SSH_SERVER_PORT'
];
const kAWSCredentialsEnvVars = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY'];

// substitute names
const kAppIdentifier = 'APP_IDENTIFIER';

/// Unpacks resources found in package into [tmpDir].
/// Appium template is used to deliver tests.
/// Scripts are used to initialize device and run tests.
Future<void> unpackResources(String tmpDir, bool isIosPoolTypeActive,
    {String appDir = '.'}) async {
  printStatus('Unpacking sylph resources to $tmpDir');
  clearDirectory(tmpDir);

  // unpack Appium template
  await writeFileImage(await readResourceImage(kAppiumTemplateZip),
      '$tmpDir/$kAppiumTemplateZip');

  // unpack Appium test spec
  await unpackFile(kAppiumTestSpecName, tmpDir);

  // unpack scripts
  await unpackScripts(tmpDir);

  // unpack build to os map file
  await unpackFile(kBuildToOsMapFileName, tmpDir);

  final nameVals = {kAppIdentifier: getAppIdentifier(appDir)};

  // unpack export options
  if (isIosPoolTypeActive) {
    await unpackFile('exportOptions.plist', 'ios',
        envVars: kExportOptionsPlistEnvVars, nameVals: nameVals);
  }

  // unpack components used in a CI environment
  if (platform.environment[kCIEnvVar] == 'true' && isIosPoolTypeActive) {
    printStatus(
        'iOS build in CI environment detected. Unpacking related resources.');
    // unpack fastlane
    await unpackFile('fastlane/Appfile', 'ios', nameVals: nameVals);
    await unpackFile('fastlane/Fastfile', 'ios');
    await unpackFile('Gemfile', 'ios');
    await unpackFile('Gemfile.lock', 'ios');

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
  if (platform.isMacOS) cmd(['chmod', 'u+x', '$dstDir/$srcPath']);
}

/// Unpack file from resources while optionally applying env vars
/// and/or name/value pairs.
Future unpackFile(String srcPath, String dstDir,
    {List<String> envVars, Map nameVals}) async {
  final resource = Resource('$kResourcesUri/$srcPath');
  String resourceStr = await resource.readAsString();

  // substitute env vars
  if (envVars != null) {
    final env = platform.environment;
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

  final file = await fs.file('$dstDir/$srcPath').create(recursive: true);
  await file.writeAsString(resourceStr, flush: true);
}

/// Gets the first app identifier found.
String getAppIdentifier(String appDir) {
  final kIosConfigPath = '$appDir/ios/Runner.xcodeproj/project.pbxproj';
  final regExp = 'PRODUCT_BUNDLE_IDENTIFIER = (.*);';
  final iOSConfigStr = fs.file(kIosConfigPath).readAsStringSync();
  return RegExp(regExp).firstMatch(iOSConfigStr)[1];
}
