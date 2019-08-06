import 'dart:io';

import 'package:sylph/sylph.dart';
import 'package:args/args.dart';

const usage =
    'usage: sylph [--help] [--config <config file>] [--devices <all|android|ios>]';
const sampleUsage = 'sample usage: sylph';

/// Uploads debug app and integration test to device farm and runs test.
main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final devicesArg = 'devices';
  final helpArg = 'help';
  final ArgParser argParser = new ArgParser(allowTrailingOptions: false)
    ..addOption(configArg,
        abbr: 'c',
        defaultsTo: 'sylph.yaml',
        help: 'Path to config file.',
        valueHelp: 'sylph.yaml')
    ..addOption(devicesArg,
        abbr: 'd',
        help: 'List availabe devices.',
        allowed: ['all', 'android', 'ios'],
        valueHelp: 'all|android|ios')
    ..addFlag(helpArg,
        help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }

  // show help
  if (argResults[helpArg] ||
      (argResults.wasParsed(configArg) && argResults.wasParsed(configArg))) {
    _showUsage(argParser);
    exit(0);
  }

  // show devices
  final devicesArgVal = argResults[devicesArg];
  if (devicesArgVal != null) {
    switch (devicesArgVal) {
      case 'all':
        for (final sylphDevice in getSylphDevices()) {
          print(sylphDevice);
        }
        break;
      case 'android':
        for (final sylphDevice in getDevices(DeviceType.android)) {
          print(sylphDevice);
        }
        break;
      case 'ios':
        for (final sylphDevice in getDevices(DeviceType.ios)) {
          print(sylphDevice);
        }
        break;
    }
    exit(0);
  }

  // validate args
  final configFilePath = argResults[configArg];
  final file = File(configFilePath);
  if (!await file.exists()) {
    _handleError(argParser, "File not found: $configFilePath");
  }

  final timestamp = sylphTimestamp();
  final sylphRunName = 'sylph run $timestamp';
  print('Starting Sylph run \'$sylphRunName\' on AWS Device Farm ...');
  print('Config file: $configFilePath');

  final sylphRunSucceeded =
      await sylphRun(configFilePath, sylphRunName, timestamp);
  print(
      'Sylph run completed in ${sylphRuntimeFormatted(timestamp, DateTime.now())}.');
  if (sylphRunSucceeded) {
    print('Sylph run \'$sylphRunName\' succeeded.');
    exit(0);
  } else {
    print('Sylph run \'$sylphRunName\' failed.');
    exit(1);
  }
}

void _handleError(ArgParser argParser, String msg) {
  stderr.writeln(msg);
  _showUsage(argParser);
  exit(1);
}

void _showUsage(ArgParser argParser) {
  print('$usage');
  print('\n$sampleUsage\n');
  print(argParser.usage);
}
