import 'dart:io';

import 'package:sylph/src/bundle.dart';
import 'package:sylph/src/utils.dart';
import 'package:test/test.dart';

main() {
  group('bundle', () {
    test('flutter', () async {
      final flutterVersion = 'v1.7.8+hotfix.4';
      // download flutter for mac and linux to staging area
      // include in bundle during bundling
      // on device farm, link to correct flutter instance
      final configStr = '''
        tmp_dir: /tmp/sylph
        flutter_version: $flutterVersion
      ''';
      Map config = await parseYamlStr(configStr);
      expect(config['flutter_version'], equals(flutterVersion));

      final stagingDir = config['tmp_dir'];
      final appiumTemplatePath = '$stagingDir/$kAppiumTemplateName';
      final testBundleDir = '$stagingDir/$kTestBundleDir';
      final defaultAppDir = '$testBundleDir/$kDefaultFlutterAppName';
      final testBundlePath = '$stagingDir/$kTestBundleName';

      // Download flutter for linux
      final flutterLinuxUnpackDir = '$stagingDir/flutter_linux';
      final flutterLinuxDir = '$flutterLinuxUnpackDir/flutter';
      Directory(flutterLinuxUnpackDir).createSync(recursive: true);
      final flutterLinuxTarPath = '$flutterLinuxUnpackDir.tar.xz';
      if (!Directory(flutterLinuxDir).existsSync()) {
        cmd([
          'curl',
          'https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_$flutterVersion-stable.tar.xz',
          '-o',
          flutterLinuxTarPath
        ], silent: false);
        expect(File(flutterLinuxTarPath).existsSync(), isTrue);
//        cmd('tar', ['xf', flutterLinuxTarPath, '-C', flutterLinuxUnpackDir]);
//        expect(Directory(flutterLinuxDir).existsSync(), isTrue);
      }

      // Download flutter for macOS
      final flutterMacOsUnpackDir = '$stagingDir/flutter_macos';
      final flutterMacOsDir = '$flutterMacOsUnpackDir/flutter';
      Directory(flutterMacOsUnpackDir).createSync(recursive: true);
      final flutterMacOsZipPath = '$flutterMacOsUnpackDir.zip';
      if (!Directory(flutterMacOsDir).existsSync()) {
        cmd([
          'curl',
          'https://storage.googleapis.com/flutter_infra/releases/stable/macos/flutter_macos_$flutterVersion-stable.zip',
          '-o',
          flutterMacOsZipPath
        ], silent: false);
        expect(File(flutterMacOsZipPath).existsSync(), isTrue);
//        cmd('unzip', ['-qq', flutterMacOsZipPath, '-d', flutterMacOsUnpackDir]);
//        expect(Directory(flutterMacOsDir).existsSync(), isTrue);
      }
    });
  });
}
