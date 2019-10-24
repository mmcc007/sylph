//import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tool_base/tool_base.dart';
import 'dart:io' as io;

/// Test for CI environment.
bool isCI() {
  return platform.environment['CI'] == 'true';
}

/// Copy [srcDir] in local filesystem to [dstDir] in another filesystem
void copyDirFs(io.Directory srcDir, Directory dstDir) {
//  print('copyDirFs: ${srcDir.path} => ${dstDir.path}');

  final srcDirEntities = srcDir.listSync();
  if (srcDirEntities.isNotEmpty) {
    createDirFs(dstDir);
    srcDirEntities.forEach((entity) {
//      print(entity.runtimeType);
      if (entity is io.File) {
//        print(
//            'copying ${entity.path} to ${dstDir.path}/${p.basename(entity.path)}');
        copyFileFs(entity, dstDir);
      }
      if (entity is io.Directory) {
        copyDirFs(
            entity,
            dstDir.fileSystem
                .directory('${dstDir.path}/${p.basename(entity.path)}'));
      }
    });
  }
}

/// Creates [dir] if doesn't exist.
void createDirFs(Directory dir) {
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
}

/// Copies [srcFile] to [dstDir] in another filesystem.
void copyFileFs(io.File srcFile, Directory dstDir) {
  final content = io.File(srcFile.path).readAsBytesSync();
  dstDir.fileSystem
      .file('${dstDir.path}/${p.basename(srcFile.path)}')
      .writeAsBytesSync(content);
}

/// List entities in [dir].
void listFiles(Directory dir) {
  dir.listSync().forEach((entity) {
    print(entity.path);
  });
}
