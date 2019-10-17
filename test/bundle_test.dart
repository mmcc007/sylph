//import 'dart:io';

import 'package:sylph/src/bundle.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/src/resources.dart';
import 'package:sylph/src/base/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart' hide Config;
import 'package:tool_base_test/tool_base_test.dart';

main() {
  group('bundle', () {
    testUsingContext('bundleFlutterTests', () async {
      final appDir = 'test/resources/test_local_pkgs/apps/app';
      final stagingDir = '/tmp/sylph_test_bundle';
      final configStr = '''
        tmp_dir: $stagingDir
      ''';
      final config = Config(configStr: configStr);
      clearDirectory(stagingDir);
      await unpackResources(stagingDir, false, appDir: 'example/default_app');
      final result = bundleFlutterTests(config, appDir: appDir);
      expect(result, equals('4.7MB'));
    }, overrides: <Type, Generator>{
      OperatingSystemUtils: () => OperatingSystemUtils(),
//      Logger: () => VerboseLogger(StdoutLogger()),
    });
  });
}

//    testUsingContext('flutter', () async {
//      final flutterVersion = 'v1.7.8+hotfix.4';
//      // download flutter for mac and linux to staging area
//      // include in bundle during bundling
//      // on device farm, link to correct flutter instance
//      final configStr = '''
//        tmp_dir: /tmp/sylph
//        flutter_version: $flutterVersion
//      ''';
//      Map config = await parseYamlStr(configStr);
//      expect(config['flutter_version'], equals(flutterVersion));
//
//      final stagingDir = config['tmp_dir'];
//      final appiumTemplatePath = '$stagingDir/$kAppiumTemplateName';
//      final testBundleDir = '$stagingDir/$kTestBundleDir';
//      final defaultAppDir = '$testBundleDir/$kDefaultFlutterAppName';
//      final testBundlePath = '$stagingDir/$kTestBundleName';
//
//      // Download flutter for linux
//      final flutterLinuxUnpackDir = '$stagingDir/flutter_linux';
//      final flutterLinuxDir = '$flutterLinuxUnpackDir/flutter';
//      fs.directory(flutterLinuxUnpackDir).createSync(recursive: true);
//      final flutterLinuxTarPath = '$flutterLinuxUnpackDir.tar.xz';
//      if (!fs.directory(flutterLinuxDir).existsSync()) {
//        await streamCmd([
//          'curl',
//          'https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_$flutterVersion-stable.tar.xz',
//          '-o',
//          flutterLinuxTarPath
//        ]);
//        expect(fs.file(flutterLinuxTarPath).existsSync(), isTrue);
//        await streamCmd(
//            ['tar', 'xf', flutterLinuxTarPath, '-C', flutterLinuxUnpackDir]);
//        expect(fs.directory(flutterLinuxDir).existsSync(), isTrue);
//      }
//
//      // Download flutter for macOS
//      final flutterMacOsUnpackDir = '$stagingDir/flutter_macos';
//      final flutterMacOsDir = '$flutterMacOsUnpackDir/flutter';
//      fs.directory(flutterMacOsUnpackDir).createSync(recursive: true);
//      final flutterMacOsZipPath = '$flutterMacOsUnpackDir.zip';
//      if (!fs.directory(flutterMacOsDir).existsSync()) {
//        await streamCmd([
//          'curl',
//          'https://storage.googleapis.com/flutter_infra/releases/stable/macos/flutter_macos_$flutterVersion-stable.zip',
//          '-o',
//          flutterMacOsZipPath
//        ]);
//        expect(fs.file(flutterMacOsZipPath).existsSync(), isTrue);
//        await streamCmd(
//            ['unzip', '-qq', flutterMacOsZipPath, '-d', flutterMacOsUnpackDir]);
//        expect(fs.directory(flutterMacOsDir).existsSync(), isTrue);
//      }
//    }, skip: true, overrides: <Type, Generator>{
//      Logger: () => VerboseLogger(StdoutLogger()),
//    });
