// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:reporting/reporting.dart';
import 'package:tool_base/tool_base.dart';

import '../base/runner/sylph_command.dart';

class ConfigCommand extends SylphCommand {
  ConfigCommand({bool verboseHelp = false}) {
    argParser.addFlag('analytics',
        negatable: true,
        help:
            'Enable or disable reporting anonymously tool usage statistics and crash reports.');
  }

  @override
  final String name = 'config';

  @override
  final String description = 'Configure Sylph settings.\n\n'
      'To remove a setting, configure it to an empty string.\n\n'
      'Sylph anonymously reports feature usage statistics and basic crash reports to help improve '
      'Sylph over time. See Sylph\'s privacy policy: https://www.mauricemccabe.com/intl/privacy/';

  @override
  final List<String> aliases = <String>['configure'];

  @override
  String get usageFooter {
    String values = config.keys.map<String>((String key) {
      String configFooter = '';
      return '  $key: ${config.getValue(key)} $configFooter';
    }).join('\n');
    if (values.isEmpty) values = '  No settings have been configured.';
    return '\nSettings:\n$values\n\n'
        'Analytics reporting is currently ${sylphUsage.enabled ? 'enabled' : 'disabled'}.';
  }

  /// Return null to disable analytics recording of the `config` command.
  @override
  Future<String> get usagePath async => null;

  @override
  Future<SylphCommandResult> runCommand() async {
    if (argResults.wasParsed('analytics')) {
      final bool value = argResults['analytics'];
      // Combines with Usage package to default to storing in home directory.
      // File is named by both [Config] and [Usage] using [kSettings].
      config.setValue('enabled', value);
//      sylphUsage.enabled = value;
      printStatus('Analytics reporting ${value ? 'enabled' : 'disabled'}.');
    }

    if (argResults.arguments.isEmpty) printStatus(usage);

    return null;
  }
}
