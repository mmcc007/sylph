import 'dart:io' as io;

import 'dart:async';

import 'package:sylph/sylph.dart';
import 'package:args/args.dart';
import 'package:tool_base/tool_base.dart';

const usage =
    'usage: sylph [--help] [--config <config file>] [--devices <all|android|ios>] [--verbose]';
const sampleUsage = 'sample usage: sylph';

final configArg = 'config';
final devicesArg = 'devices';
final verboseArg = 'verbose';
final helpArg = 'help';
ArgResults argResults;
ArgParser argParser;

/// Uploads debug app and integration test to device farm and runs test.
main(List<String> arguments) async {
  argParser = ArgParser(allowTrailingOptions: false)
    ..addOption(configArg,
        abbr: 'c',
        defaultsTo: 'sylph.yaml',
        help: 'Path to config file.',
        valueHelp: 'sylph.yaml')
    ..addOption(devicesArg,
        abbr: 'd',
        help: 'List devices available in cloud.',
        allowed: ['all', 'android', 'ios'],
        valueHelp: 'all|android|ios')
    ..addFlag(verboseArg,
        abbr: 'v',
        help: 'Noisy logging, including all shell commands executed.',
        negatable: false)
    ..addFlag(helpArg,
        abbr: 'h', help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }

  // show help
  if (argResults[helpArg] ||
      (argResults.wasParsed(configArg) && argResults.wasParsed(devicesArg))) {
    _showUsage(argParser);
    exit(0);
  }

  if (argResults.wasParsed(verboseArg)) {
    Logger verboseLogger = VerboseLogger(
        platform.isWindows ? WindowsStdoutLogger() : StdoutLogger());
    await runInContext<void>(() async {
      await run();
    }, overrides: <Type, Generator>{
      Logger: () => verboseLogger,
    });
  } else {
    await runInContext<void>(() async {
      await run();
    });
  }
}

Future run() async {
  // show devices
  final devicesArgVal = argResults[devicesArg];
  if (devicesArgVal != null) {
    switch (devicesArgVal) {
      case 'all':
        printDeviceFarmDevices(getDeviceFarmDevices());
        break;
      case 'android':
        printDeviceFarmDevices(getDeviceFarmDevicesByType(DeviceType.android));
        break;
      case 'ios':
        printDeviceFarmDevices(getDeviceFarmDevicesByType(DeviceType.ios));
        break;
    }
    exit(0);
  }

  // validate args
  final configFilePath = argResults[configArg];
  final file = fs.file(configFilePath);
  if (!await file.exists()) {
    _handleError(argParser, "File not found: $configFilePath");
  }

  final timestamp = sylphTimestamp();
  final sylphRunName = 'sylph run $timestamp';
  printStatus('Starting Sylph run \'$sylphRunName\' on AWS Device Farm ...');
  printStatus('Config file: $configFilePath');

  final sylphRunSucceeded = await sylphRun(configFilePath, sylphRunName,
      timestamp, argResults.wasParsed(verboseArg));
  printStatus(
      'Sylph run completed in ${sylphRuntimeFormatted(timestamp, DateTime.now())}.');
  if (sylphRunSucceeded) {
    printStatus('Sylph run \'$sylphRunName\' succeeded.');
    exit(0);
  } else {
    printStatus('Sylph run \'$sylphRunName\' failed.');
    exit(1);
  }
}

void printDeviceFarmDevices(List<DeviceFarmDevice> deviceFarmDevices) {
  for (final deviceFarmDevice in deviceFarmDevices) {
    printStatus(deviceFarmDevice.toString());
  }
  printStatus('${deviceFarmDevices.length} devices');
}

void _handleError(ArgParser argParser, String msg) {
  io.stderr.writeln(msg);
  _showUsage(argParser);
  exit(1);
}

void _showUsage(ArgParser argParser) {
  print('$usage');
  print('\n$sampleUsage\n');
  print(argParser.usage);
}
