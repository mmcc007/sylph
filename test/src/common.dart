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
    if (!dstDir.existsSync()) {
      dstDir.createSync(recursive: true);
    }
    srcDirEntities.forEach((entity) {
//      print(entity.runtimeType);
      if (entity is io.File) {
//        print(
//            'copying ${entity.path} to ${dstDir.path}/${p.basename(entity.path)}');
        final content = io.File(entity.path).readAsBytesSync();
        dstDir.fileSystem
            .file('${dstDir.path}/${p.basename(entity.path)}')
            .writeAsBytesSync(content);
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

/// List entities in [dir].
void listFiles(Directory dir) {
  dir.listSync().forEach((entity) {
    print(entity.path);
  });
}
