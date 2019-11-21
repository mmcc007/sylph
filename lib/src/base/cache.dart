///*
// * Copyright 2019 The Sylph Authors. All rights reserved.
// *  Sylph runs Flutter integration tests on real devices in the cloud.
// *  Use of this source code is governed by a GPL-style license that can be
// *  found in the LICENSE file.
// */
//
//import 'package:sylph/runner.dart';
//import 'package:tool_base/tool_base.dart';
//
//Cache get cache => Cache.instance;
//
///// A wrapper around the `bin/cache/` directory.
//class Cache {
//  // Initialized by FlutterCommandRunner on startup.
//  static String flutterRoot;
//
//  static Cache get instance => context.get<Cache>();
//
//  /// Return the top-level directory in the cache; this is `bin/cache`.
//  Directory getRoot() {
//    return fs.directory(platform.environment['HOME']);
//  }
//
//  String getStampFor(String artifactName) {
//    final File stampFile = getStampFileFor(artifactName);
//    return stampFile.existsSync()
//        ? stampFile.readAsStringSync().trim()
//        : null; // todo read json
//  }
//
//  void setStampFor(String artifactName, String version) {
//    getStampFileFor(artifactName).writeAsStringSync(version); // todo write json
//  }
//
//  File getStampFileFor(String artifactName) {
////    return fs.file(fs.path.join(getRoot().path, '$artifactName.stamp'));
//    return fs.file(fs.path.join(getRoot().path, '.$kSettings'));
//  }
//
//  /// Returns `true` if either [entity] is older than the tools stamp or if
//  /// [entity] doesn't exist.
//  bool isOlderThanToolsStamp(FileSystemEntity entity) {
//    final File flutterToolsStamp = getStampFileFor('flutter_tools');
//    return isOlderThanReference(
//        entity: entity, referenceFile: flutterToolsStamp);
//    // todo pass timestamp and compare to now
//  }
//}
