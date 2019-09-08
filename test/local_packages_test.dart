//import 'dart:io';

import 'package:sylph/src/context_runner.dart';
import 'package:sylph/src/local_packages.dart';
import 'package:sylph/src/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import 'src/common.dart';

main() {
  group('local package manager', () {
    final srcDir = 'test/resources/test_local_pkgs/apps';
    final dstDir = '/tmp/test_local_pkgs';
    final appName = 'app';
    final appSrcDir = '$srcDir/$appName';
    final appDstDir = '$dstDir/$appName';
    LocalPackageManager localPackageManager;

    setUp(() {
      clearDirectory(dstDir);
      runInContext<void>(() {
        LocalPackageManager.copy(appSrcDir, appDstDir, force: true);
        localPackageManager =
            LocalPackageManager(appDstDir, isAppPackage: true);
        localPackageManager.installPackages(appSrcDir);
      }, overrides: <Type, Generator>{
//        Logger: () => VerboseLogger(StdoutLogger()),
      });
    });

    testUsingContext('copy app package', () {
      expect(fs.directory(appDstDir).existsSync(), isTrue);
    });

    testUsingContext('install local packages', () {
//      localPackageManager.installPackages(appSrcDir);
      final expectedLocalPackage = 'local_package';
      final expectedSharedLocalPackage = 'shared_package';
      expect(fs.directory('$appDstDir/$expectedLocalPackage').existsSync(),
          isTrue);
      expect(
          fs.directory('$appDstDir/$expectedSharedLocalPackage').existsSync(),
          isTrue);
    });

    testUsingContext('cleanup apps pubspec.yaml', () {
//      localPackageManager.installPackages(appSrcDir);

      final expectedPubSpec = '''
name: "app"
dependencies: 
  local_package: 
    path: "local_package"
''';
      expect(fs.file('$appDstDir/pubspec.yaml').readAsStringSync(),
          expectedPubSpec);
    });

    testUsingContext(
        'cleanup local dependencies of dependencies if at different directory levels',
        () {
//      localPackageManager.installPackages(appSrcDir);

      final expectedPubSpecLocal = '''
name: "local_package"
dependencies: 
  shared_package: 
    path: "../shared_package"
environment: 
  sdk: ">=2.0.0 <3.0.0"
''';
      expect(
          fs.file('$appDstDir/local_package/pubspec.yaml').readAsStringSync(),
          expectedPubSpecLocal);

      final expectedPubSpecShared = '''
name: "shared_package"
dependencies: 
  path: "^1.6.4"
environment: 
  sdk: ">=2.0.0 <3.0.0"
''';
      expect(
          fs.file('$appDstDir/shared_package/pubspec.yaml').readAsStringSync(),
          expectedPubSpecShared);
    });

    testUsingContext('get dependencies in new project', () {
//      localPackageManager.installPackages(appSrcDir);
      expect(cmd(['flutter', 'packages', 'get'], workingDirectory: appDstDir),
          isNotEmpty);
    }, skip: isCI());
  });
}
