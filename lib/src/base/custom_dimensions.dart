/*
 * Copyright 2019 The Sylph Authors. All rights reserved.
 *  Sylph runs Flutter integration tests on real devices in the cloud.
 *  Use of this source code is governed by a GPL-style license that can be
 *  found in the LICENSE file.
 */

import 'package:sylph/src/base/reporting/reporting.dart';

CustomDimensions get customDimensions => CustomDimensions.instance;

class CustomDimensions extends Dimensions {
  // gets called once
  CustomDimensions._internal() {
    dimensions = _customDimensions;
    validate();
  }

  static final CustomDimensions instance = CustomDimensions._internal();

//  Map<String, String> _customDimensions = {
//    'cd3': 'commandHasTerminal',
//    'cd4': 'commandRunIsEmulator',
//    'cd5': 'commandRunTargetName',
//    'cd6': 'commandRunTargetOsVersion',
//    'cd7': 'commandRunProjectHostLanguage',
//  };

  Map<String, String> _customDimensions = {
//    'localTime': 'cd2',
    'commandHasTerminal': 'cd3',
    'commandRunIsEmulator': 'cd4',
    'commandRunTargetName': 'cd5',
    'commandRunTargetOsVersion': 'cd6',
    'commandRunProjectHostLanguage': 'cd7',
  };

  String get commandHasTerminal => dimensions['commandHasTerminal'];

  String get commandRunIsEmulator => dimensions['commandRunIsEmulator'];

  String get commandRunTargetName => dimensions['commandRunTargetName'];

  String get commandRunTargetOsVersion => dimensions['commandRunTargetOsVersion'];

  String get commandRunProjectHostLanguage => dimensions['commandRunProjectHostLanguage'];
}
