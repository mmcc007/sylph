import 'dart:io';

import 'package:sylph/sylph.dart';
import 'package:args/args.dart';

const usage = 'usage: sylph [--help] [--config <config file>]';
const sampleUsage = 'sample usage: sylph';

/// Uploads debug app and integration test to device farm and runs test.
main(List<String> arguments) async {
  ArgResults argResults;

  final configArg = 'config';
  final helpArg = 'help';
  final ArgParser argParser = new ArgParser(allowTrailingOptions: false)
    ..addOption(configArg,
        abbr: 'c',
        defaultsTo: 'sylph.yaml',
        help: 'Path to config file.',
        valueHelp: 'sylph.yaml')
    ..addFlag(helpArg,
        help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }

  // show help
  if (argResults[helpArg]) {
    _showUsage(argParser);
    exit(0);
  }

  // validate args
  final configFilePath = argResults[configArg];
  final file = File(configFilePath);
  if (!await file.exists()) {
    _handleError(argParser, "File not found: $configFilePath");
  }

  final timestamp = genTimestamp();
  final sylphRunName = 'sylph run $timestamp';
  print('Starting Sylph run \'$sylphRunName\' on AWS Device Farm ...');
  print('Config file: $configFilePath');

  // Parse config file
  Map config = await parseYaml(configFilePath);

  final sylphRunTimeout = config['sylph_timeout'];

  // Setup project (if needed)
  final projectArn =
      setupProject(config['project_name'], config['default_job_timeout']);

  final sylphRunSucceeded = await sylphRun(
      config, projectArn, sylphRunName, sylphRunTimeout, timestamp);
  if (sylphRunSucceeded) {
    print('Sylph run \'$sylphRunName\' suceeded.');
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
