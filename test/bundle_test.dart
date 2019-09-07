//import 'dart:io';

import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:process/process.dart';
import 'package:sylph/src/bundle.dart';
import 'package:sylph/src/context_runner.dart';
import 'package:sylph/src/local_packages.dart';
import 'package:sylph/src/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import 'src/common.dart';

main() {
  group('bundle', () {
    final appDir = 'test/resources/test_local_pkgs/apps/app';
    final stagingDir = '/tmp/screenshots_test';
    final bundleDir = '$stagingDir/$kTestBundleDir';
    final bundleZipName = '$stagingDir/$kTestBundleName';
    final bundleAppDir = '$bundleDir/$kDefaultFlutterAppName';

    FakeProcessManager fakeProcessManager;

    setUp(() async {
      fakeProcessManager = FakeProcessManager();
      // create fake app in bundle
//      copyFiles(appDir, bundleAppDir);
      await runInContext<void>(() {
        LocalPackageManager.copy(appDir, bundleAppDir, force: true);
        final localPackageManager =
            LocalPackageManager(appDir, isAppPackage: true);
        localPackageManager.installPackages(appDir);
      });
    });

    testUsingContext('bundle flutter tests', () async {
      fakeProcessManager.calls = [
        Call(
            'unzip -q $stagingDir/appium_bundle.zip -d $stagingDir/test_bundle',
            null),
        Call('mkdir $bundleAppDir', null),
        Call('cp -r $appDir $bundleAppDir', null),
        Call('rm -rf $bundleAppDir/build', null),
        Call('cp -r $stagingDir/script $bundleAppDir', null),
        Call('cp $stagingDir/build_to_os.txt $bundleAppDir', null),
        Call('rm -rf $bundleAppDir/ios/Flutter/Flutter.framework', null),
        Call('rm -rf $bundleAppDir/ios/Flutter/App.framework', null),
        Call('zip -rq $bundleZipName $bundleDir', null),
        Call('stat -f%z $bundleZipName', ProcessResult(0, 0, '5000000', '')),
      ];

      final result =
          await bundleFlutterTests({'tmp_dir': stagingDir}, appDir: appDir);
      expect(result, equals(5));
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
    });

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
  });
}
