import 'dart:convert';
//import 'dart:io';

import 'package:sylph/src/base/utils.dart';

import 'copy_path.dart';
import 'package:tool_base/tool_base.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:yamlicious/yamlicious.dart';

/// Installs any local packages to the app project at the same level.
///
/// Includes handling of local packages that have other local packages using
/// recursion.
///
/// Sample usage:
/// ```
/// LocalPackageManager.copy(srcDir, dstDir, force: true);
/// final localPackageManager = LocalPackageManager(dstDir, isAppPackage: true);
/// localPackageManager.installPackages(srcDir).
/// ```
class LocalPackageManager {
  LocalPackageManager(this.packageDir, {this.isAppPackage = false}) {
    printTrace('LocalPackageManager(${this.packageDir}, ${this.isAppPackage})');
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
  void installPackages(String srcDir) {
    String dstDir;
    if (isAppPackage) {
      dstDir = packageDir;
    } else {
      dstDir = path.dirname(packageDir);
    }
//    printTrace(
//        '\tinstallPackages:\n\t\tsrcDir=$srcDir\n\t\tdstDir=$dstDir\n\t\tisAppPackage=$isAppPackage');
    _processPubSpec(srcDir: srcDir, dstDir: dstDir);
    _cleanupPubSpec();
  }

  // set paths to dependent local packages
  void _cleanupPubSpec() {
//    printTrace(
//        '\t_cleanupPubSpec:\n\t\tisAppPackage=$isAppPackage\n\t\tpath=${_pubSpec.path}');
    // set path to local dependencies
    _processPubSpec(setPkgPath: true);
    // convert map to json, to string, parse as yaml, convert to yaml string and save
    _pubSpec.writeAsStringSync(toYamlString(loadYaml(jsonEncode(_pubSpecMap))));
  }

  // scan pubSpec for local packages and copy to dstDir, or,
  // scan pubSpec for local packages and adjust local paths.
  void _processPubSpec(
      {String srcDir, String dstDir, bool setPkgPath = false}) {
//    if (!setPkgPath && (srcDir == null || dstDir == null)) {
//      throw 'Error: cannot process ${_pubSpec.path}\nsrcDir=$srcDir\ndstDir=$dstDir\nsetPackagePath=$setPkgPath';
//    }
    _pubSpecMap.forEach((k, v) {
      if (k == kDependencies || k == kDevDependencies) {
        v?.forEach((pkgName, pkgInfo) {
          if (pkgInfo is Map) {
            pkgInfo.forEach((k, v) {
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
                  copy(pkgSrcDir, pkgDstDir);
                  // install any local packages within this local package
                  final localPkgMgr = LocalPackageManager(pkgDstDir);
                  localPkgMgr.installPackages(pkgSrcDir);
                }
              }
            });
          }
        });
      }
    });
  }

  /// Copy dir. Assumes path syntax is specific to current platform.
  static copy(String srcDir, String dstDir, {bool force = false}) {
//    printTrace('LocalPackageManager: copy($srcDir, $dstDir, force: $force)');
    // do not copy if package already exists
    if (!fs.directory(dstDir).existsSync() || force) {
//      if (platform.isWindows) {
//        cmd(['xcopy', '$srcDir', '$dstDir', '/e', '/i', '/q']);
//      } else {
//        cmd(['cp', '-r', '$srcDir', '$dstDir']);
//      }
//      print('copyFiles($srcDir, $dstDir)');
      fs.directory(dstDir).createSync();
//      copyDir(srcDir, dstDir);
      copyPathSync(srcDir, dstDir);
    }
  }
}
