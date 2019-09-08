import 'dart:async';
import 'dart:convert';
//import 'dart:io';

import 'package:sylph/src/utils.dart';
import 'package:tool_base/tool_base.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:yamlicious/yamlicious.dart';

/// Installs any local packages to the app project at the same level.
/// Includes handling of local packages that have other local packages using
/// recursion.
/// Initialize the app project dir using [LocalPackageManager.copy].
/// Then pass the bundle's app dir as the [packageDir] and set [isAppPackage]
/// to true.
class LocalPackageManager {
  LocalPackageManager(this.packageDir, {this.isAppPackage = false}) {
//    printStatus('LocalPackageManager\n\tpackageDir=$packageDir');
    assert(packageDir != null);
    assert(isAppPackage != null);
    _pubSpec = fs.file('$packageDir/$kPubSpecYamlName');
    _pubSpecMap = jsonDecode(jsonEncode(loadYaml(_pubSpec.readAsStringSync())));
  }
  final String packageDir;
  final bool isAppPackage;
  File _pubSpec;
  Map _pubSpecMap;

  // pubspec.yaml constants
  final kPubSpecYamlName = 'pubspec.yaml';
  final kDependencies = 'dependencies';
  final kDevDependencies = 'dev_dependencies';
  final kLocalDependencyPath = 'path';

  /// Install any local packages from [srcDir] and their local packages.
  /// All local packages end-up at the same level in new project.
  /// Adjust each pubspec.yaml to the new project.
  Future installPackages(String srcDir) async {
    String dstDir;
    if (isAppPackage) {
      dstDir = packageDir;
    } else {
      dstDir = path.dirname(packageDir);
    }
//    printStatus(
//        'copyLocalPackages:\n\tsrcDir=$srcDir\n\tdstDir=$dstDir\n\tisAppPackage=$isAppPackage');
    await _processPubSpec(srcDir: srcDir, dstDir: dstDir);
    await _cleanupPubSpec();
  }

  // set paths to dependent local packages
  Future _cleanupPubSpec() async {
//    printStatus(
//        '_cleanupPubSpec:\n\tisAppPackage=$isAppPackage\n\tpath=${_pubSpec.path}');
    // set path to local dependencies
    await _processPubSpec(setPkgPath: true);
    // convert map to json, to string, parse as yaml, convert to yaml string and save
    _pubSpec.writeAsStringSync(toYamlString(loadYaml(jsonEncode(_pubSpecMap))));
  }

  // scan pubSpec for local packages and copy to dstDir, or,
  // scan pubSpec for local packages and adjust local paths.
  Future _processPubSpec(
      {String srcDir, String dstDir, bool setPkgPath = false}) async {
    if (!setPkgPath && (srcDir == null || dstDir == null)) {
      throw 'Error: cannot process ${_pubSpec.path}\nsrcDir=$srcDir\ndstDir=$dstDir\nsetPackagePath=$setPkgPath';
    }
    await _pubSpecMap.forEach((k, v) async {
      if (k == kDependencies || k == kDevDependencies) {
        await v?.forEach((pkgName, pkgInfo) async {
          if (pkgInfo is Map) {
            await pkgInfo.forEach((k, v) async {
              if (k == kLocalDependencyPath) {
                // found a local package
                if (setPkgPath) {
                  // update local package path
                  final pkgPath = isAppPackage ? pkgName : '../$pkgName';
                  pkgInfo[kLocalDependencyPath] = pkgPath;
                } else {
                  // copy local package
                  final pkgSrcDir =
                      path.joinAll([srcDir, path.joinAll(v.split('/'))]);
                  final pkgDstDir = path.join(dstDir, pkgName);
                  await copy(pkgSrcDir, pkgDstDir);
                  // install any local packages within this local package
                  final localPkgMgr = LocalPackageManager(pkgDstDir);
                  await localPkgMgr.installPackages(pkgSrcDir);
                }
              }
            });
          }
        });
      }
    });
  }

  /// Copy dir. Assumes path syntax is specific to current platform.
  static Future copy(String srcDir, String dstDir, {bool force = false}) async {
    // do not copy if package already exists
    if (!fs.directory(dstDir).existsSync() || force) {
//      if (platform.isWindows) {
//        cmd(['xcopy', '$srcDir', '$dstDir', '/e', '/i', '/q']);
//      } else {
//        cmd(['cp', '-r', '$srcDir', '$dstDir']);
//      }
//      print('copyFiles($srcDir, $dstDir)');
      await copyFiles(srcDir, dstDir);
    }
  }
}
