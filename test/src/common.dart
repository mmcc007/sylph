//import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tool_base/tool_base.dart';

/// Test for CI environment.
bool isCI() {
  return platform.environment['CI'] == 'true';
}

/// Copy files from [srcDir] to [dstDir].
/// Create dstDir if none exists
void copyFiles(String srcDir, dstDir) {
  if (!fs.directory(dstDir).existsSync()) {
    fs.directory(dstDir).createSync(recursive: true);
  }
  fs.directory(srcDir).listSync().forEach((entity) {
    print('entity ${entity.path}');
    if (entity is File) {
      print('copying ${entity.path} to $dstDir/${p.basename(entity.path)}');
      fs.file(entity.path).copy('$dstDir/${p.basename(entity.path)}');
    }
  });
}
