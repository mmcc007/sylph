/*
 * Copyright 2019 The Sylph Authors. All rights reserved.
 *  Sylph runs Flutter integration tests on real devices in the cloud.
 *  Use of this source code is governed by a GPL-style license that can be
 *  found in the LICENSE file.
 */

import 'dart:async';

//import 'package:flutter_tools/src/cache.dart';
//import 'package:flutter_tools/src/reporting/reporting.dart';
//import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:mockito/mockito.dart';
import 'package:reporting/reporting.dart';
import 'package:sylph/src/base/runner/sylph_command.dart';

typedef CommandFunction = Future<SylphCommandResult> Function();

class DummySylphCommand extends SylphCommand {

  DummySylphCommand({
    this.shouldUpdateCache = false,
    this.noUsagePath  = false,
    this.commandFunction,
  });

  final bool noUsagePath;
  final CommandFunction commandFunction;

  @override
  final bool shouldUpdateCache;

  @override
  String get description => 'does nothing';

  @override
  Future<String> get usagePath => noUsagePath ? null : super.usagePath;

  @override
  String get name => 'dummy';

  @override
  Future<SylphCommandResult> runCommand() async {
    return commandFunction == null ? null : await commandFunction();
  }
}

//class MockitoCache extends Mock implements Cache {}

class MockitoUsage extends Mock implements Usage {}
