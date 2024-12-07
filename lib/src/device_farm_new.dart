import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'models/device.dart';
import 'utils/tool_base.dart';

/// AWS Device Farm test runner.
class DeviceFarm {
  /// Creates a new project in AWS Device Farm.
  Future<String> createProject(String projectName) async {
    printStatus('Creating new project for \'$projectName\' ...');
    final result = await runCommand(
      'aws',
      ['devicefarm', 'create-project', '--name', projectName, '--output', 'json'],
      failureMessage: 'Failed to create project',
    );
    final Map<String, dynamic> response = jsonDecode(result);
    return response['project']['arn'] as String;
  }

  /// Sets up a device pool in AWS Device Farm.
  Future<String> setupDevicePool(DevicePool devicePool, String projectArn) async {
    printStatus('Setting up device pool \'${devicePool.name}\' ...');
    final rules = [
      {
        'attribute': 'ARN',
        'operator': 'IN',
        'value': jsonEncode(devicePool.devices.map((device) => device.arn).toList()),
      }
    ];

    final result = await runCommand(
      'aws',
      [
        'devicefarm',
        'create-device-pool',
        '--project-arn',
        projectArn,
        '--name',
        devicePool.name,
        '--rules',
        jsonEncode(rules),
        '--output',
        'json',
      ],
      failureMessage: 'Failed to create device pool',
    );

    final Map<String, dynamic> response = jsonDecode(result);
    return response['devicePool']['arn'] as String;
  }

  /// Upload a file to AWS Device Farm
  Future<String> uploadFile(String projectArn, String filePath, String type) async {
    final fileName = path.basename(filePath);
    final createUploadResult = await runCommand(
      'aws',
      [
        'devicefarm',
        'create-upload',
        '--project-arn',
        projectArn,
        '--name',
        fileName,
        '--type',
        type,
        '--output',
        'json',
      ],
      failureMessage: 'Failed to create upload',
    );

    final upload = jsonDecode(createUploadResult);
    final uploadUrl = upload['upload']['url'] as String;
    final uploadArn = upload['upload']['arn'] as String;

    // Upload the file using AWS CLI
    await runCommand(
      'aws',
      [
        's3',
        'cp',
        filePath,
        uploadUrl,
        '--no-sign-request',
      ],
      failureMessage: 'Failed to upload file',
    );

    // Wait for the upload to be processed
    while (true) {
      final getUploadResult = await runCommand(
        'aws',
        [
          'devicefarm',
          'get-upload',
          '--arn',
          uploadArn,
          '--output',
          'json',
        ],
        failureMessage: 'Failed to get upload status',
      );

      final uploadStatus = jsonDecode(getUploadResult)['upload']['status'] as String;
      if (uploadStatus == 'SUCCEEDED') {
        break;
      } else if (uploadStatus == 'FAILED') {
        throw Exception('Upload failed');
      }

      await Future.delayed(const Duration(seconds: 5));
    }

    return uploadArn;
  }

  /// Runs tests on AWS Device Farm.
  Future<void> runTests({
    required String projectName,
    required DevicePool devicePool,
    required YamlMap? testSuite,
  }) async {
    if (testSuite == null) {
      printError('No test suite specified');
      exit(1);
    }

    final projectArn = await createProject(projectName);
    final devicePoolArn = await setupDevicePool(devicePool, projectArn);

    final appFile = testSuite['app'] as String;
    if (!File(appFile).existsSync()) {
      printError('App file not found: $appFile');
      exit(1);
    }

    final testSpecFile = testSuite['test_spec'] as String;
    if (!File(testSpecFile).existsSync()) {
      printError('Test spec file not found: $testSpecFile');
      exit(1);
    }

    printStatus('Running tests...');
    
    // Upload app
    printStatus('Uploading app...');
    final appUploadArn = await uploadFile(projectArn, appFile, 'ANDROID_APP');

    // Upload test spec
    printStatus('Uploading test spec...');
    final testSpecUploadArn = await uploadFile(projectArn, testSpecFile, 'APPIUM_NODE_TEST_SPEC');

    // Schedule run
    printStatus('Scheduling test run...');
    final scheduleRunResult = await runCommand(
      'aws',
      [
        'devicefarm',
        'schedule-run',
        '--project-arn',
        projectArn,
        '--app-arn',
        appUploadArn,
        '--device-pool-arn',
        devicePoolArn,
        '--name',
        'Test Run ${DateTime.now().toIso8601String()}',
        '--test',
        jsonEncode({
          'type': 'APPIUM_NODE',
          'testSpecArn': testSpecUploadArn,
        }),
        '--output',
        'json',
      ],
      failureMessage: 'Failed to schedule test run',
    );

    final run = jsonDecode(scheduleRunResult);
    final runArn = run['run']['arn'] as String;

    printStatus('Test run scheduled with ARN: $runArn');
    printStatus('View the run in AWS Device Farm console.');
  }
}
