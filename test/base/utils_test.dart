import 'dart:io' as io;

import 'package:file/memory.dart';
import 'package:sylph/src/base/copy_path.dart';
import 'package:sylph/src/base/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import '../src/common.dart';

main() {
  group('utils', () {
//    group('local filesystem', () {
//      testUsingContext('copyDir', () {
//        final srcDirPath = 'test/resources/test_local_pkgs';
//        final dstDirPath = '/tmp/test_copy_dir';
//        clearDirectory(dstDirPath);
//        copyDir(srcDirPath, dstDirPath);
////        io.Directory(dstDirPath)
////            .listSync()
////            .forEach((e) => printTrace(e.toString()));
//        expect(io.Directory(dstDirPath).listSync().length, equals(3));
//      }, overrides: <Type, Generator>{
////        Logger: () => VerboseLogger(StdoutLogger()),
//      });
//    });

    group('in memory filesystem', () {
      MemoryFileSystem fs;

      setUp(() async {
        fs = MemoryFileSystem();
        copyDirFs(io.Directory('test/resources/test_local_pkgs'),
            fs.directory('/app_dir'));
      });
      testUsingContext('copyPathSync', () {
        final srcDirPath = '/app_dir';
        final dstDirPath = '/tmp/test_copy_dir';
        clearDirectory(dstDirPath);
        copyPathSync(srcDirPath, dstDirPath);
//        fs
//            .directory(dstDirPath)
//            .listSync()
//            .forEach((e) => printTrace(e.toString()));
        expect(fs.directory(dstDirPath).listSync().length, equals(3));
      }, overrides: <Type, Generator>{
//        Logger: () => VerboseLogger(StdoutLogger()),
        FileSystem: () => fs,
      });
    });
  });
}
