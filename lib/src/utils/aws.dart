import 'dart:convert';
import 'process.dart';
import 'logging.dart';

/// Run an AWS Device Farm command and return the result as a Map.
Future<Map<String, dynamic>> deviceFarmCmd(List<String> args) async {
  final result = await runCommand(
    'aws',
    ['devicefarm', ...args],
    environment: {'AWS_PAGER': ''},
  );

  if (!result.success) {
    printError('Error running aws devicefarm command:');
    printError(result.stderr);
    throw Exception('aws devicefarm command failed');
  }

  try {
    return json.decode(result.stdout) as Map<String, dynamic>;
  } catch (e) {
    printError('Error parsing aws devicefarm command output:');
    printError(result.stdout);
    rethrow;
  }
}

/// Run an AWS S3 command.
Future<void> s3Cmd(List<String> args) async {
  final result = await runCommand('aws', ['s3', ...args]);

  if (!result.success) {
    printError('Error running aws s3 command:');
    printError(result.stderr);
    throw Exception('aws s3 command failed');
  }
}
