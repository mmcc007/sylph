import 'dart:async';

import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:file/memory.dart';
import 'package:process/process.dart';
import 'package:sylph/src/base/concurrent_jobs.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/src/device_farm.dart';
import 'package:sylph/src/resources.dart';
import 'package:sylph/src/sylph_run.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart' hide Config;
import 'package:tool_base_test/tool_base_test.dart';
import 'dart:io' as io;

import 'src/common.dart';

const kTestProjectArn =
    'arn:aws:devicefarm:us-west-2:122621792560:project:908d123f-af8c-4d4b-9b86-65d3d51a0e49';
// successful run with multiple jobs
const kSuccessfulRunArn =
    'arn:aws:devicefarm:us-west-2:122621792560:run:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd';
const kFirstJobArn =
    'arn:aws:devicefarm:us-west-2:122621792560:job:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000';

main() {
  final projectName = 'test sylph run';
  final defaultJobTimeoutMinutes = '10';
  final projectArn =
      'arn:aws:devicefarm:us-west-2:122621792560:project:fake-project-id';
  final stagingDir = '/tmp/test_sylph_run';
  final appiumTemplateZip = '$stagingDir/$kAppiumTemplateZip';
  final bundleDir = '$stagingDir/$kTestBundleDir';
  final bundleZip = '$stagingDir/$kTestBundleZip';

  final listDevicesCall = Call(
      'aws devicefarm list-devices',
      ProcessResult(
          0,
          0,
          jsonEncode(
            {
              "devices": [
                {
                  "arn":
                      "arn:aws:devicefarm:us-west-2::device:70D5B22608A149568923E4A225EC5E04",
                  "name": "Samsung Galaxy Note 4 SM-N910H",
                  "manufacturer": "Samsung",
                  "model": "Galaxy Note 4 SM-N910H",
                  "modelId": "SM-N910H",
                  "formFactor": "PHONE",
                  "platform": "ANDROID",
                  "os": "5.0.1",
                  "cpu": {
                    "frequency": "MHz",
                    "architecture": "armeabi-v7a",
                    "clock": 1300.0
                  },
                  "resolution": {"width": 1440, "height": 2560},
                  "heapSize": 512000000,
                  "memory": 32000000000,
                  "image": "70D5B22608A149568923E4A225EC5E04",
                  "remoteAccessEnabled": false,
                  "remoteDebugEnabled": false,
                  "fleetType": "PUBLIC",
                  "availability": "AVAILABLE"
                },
                {
                  "arn":
                      "arn:aws:devicefarm:us-west-2::device:352FDCFAA36C43AC8228DC8F23355272",
                  "name": "Apple iPhone 6 Plus",
                  "manufacturer": "Apple",
                  "model": "iPhone 6 Plus",
                  "modelId": "A1522",
                  "formFactor": "PHONE",
                  "platform": "IOS",
                  "os": "10.0.2",
                  "cpu": {
                    "frequency": "Hz",
                    "architecture": "arm64",
                    "clock": 0.0
                  },
                  "resolution": {"width": 1080, "height": 1920},
                  "heapSize": 0,
                  "memory": 16000000000,
                  "image": "352FDCFAA36C43AC8228DC8F23355272",
                  "remoteAccessEnabled": false,
                  "remoteDebugEnabled": false,
                  "fleetType": "PUBLIC",
                  "availability": "HIGHLY_AVAILABLE"
                }
              ]
            },
          ),
          ''));

  final startRunCalls = [
    listDevicesCall,
    Call('aws devicefarm list-projects',
        ProcessResult(0, 0, '{"projects":[]}', '')),
    Call(
        'aws devicefarm create-project --name $projectName --default-job-timeout-minutes $defaultJobTimeoutMinutes',
        ProcessResult(
            0,
            0,
            jsonEncode({
              "project": {
                "arn": "$projectArn",
                "name": "$projectName",
                "defaultJobTimeoutMinutes": defaultJobTimeoutMinutes,
                "created": 1567902055.614
              }
            }),
            '')),
    Call('chmod u+x $stagingDir/script/test_android.sh', null),
    Call('chmod u+x $stagingDir/script/test_ios.sh', null),
    Call('chmod u+x $stagingDir/script/local_utils.sh', null),
    Call('unzip -o -q $appiumTemplateZip -d $bundleDir', null),
    Call('zip -r -q $bundleZip .', null,
        sideEffects: () => fs.file(bundleZip).createSync(recursive: true)),
  ];

  group('sylph run', () {
    FakeProcessManager fakeProcessManager;
    MemoryFileSystem fs;

    setUp(() async {
      fakeProcessManager = FakeProcessManager();
      fs = MemoryFileSystem();
    });

    testUsingContext('run ', () async {
      final projectName = 'test sylph run';
      final defaultJobTimeoutMinutes = '10';
      final jobTimeoutMinutes = '15';
      final projectArn =
          'arn:aws:devicefarm:us-west-2:122621792560:project:fake-project-id';
      final stagingDir = '/tmp/test_sylph_run';
      final appDir = '.';

      // copy app to memory file system
      copyDirFs(io.Directory('example/default_app'), fs.directory(appDir));

      final mainRunCalls = [
        Call(
            'aws devicefarm get-upload --arn arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/94210aaa-5b94-4fe4-8535-80f2c6b8a847',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/94210aaa-5b94-4fe4-8535-80f2c6b8a847",
                    "name": "app.apk",
                    "created": 1567929241.253,
                    "type": "ANDROID_APP",
                    "status": "$kUploadSucceeded",
                    "url": "https://fake-url",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'aws devicefarm create-upload --project-arn $projectArn --name test_bundle.zip --type APPIUM_PYTHON_TEST_PACKAGE',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/d73555c0-a254-48ad-b340-24b8eee1f6c2",
                    "name": "test_bundle.zip",
                    "created": 1567929796.433,
                    "type": "APPIUM_PYTHON_TEST_PACKAGE",
                    "status": "INITIALIZED",
                    "url":
                        "https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3Afake-project-id/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3Afake-project-id/d73555c0-a254-48ad-b340-24b8eee1f6c2/test_bundle.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T080316Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=4f35642010283b813b8aaf4a2e8c64d7d81c99ef1d50eb73d466cebeb1ba5493",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'curl -T /tmp/test_sylph_run/test_bundle.zip https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3Afake-project-id/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3Afake-project-id/d73555c0-a254-48ad-b340-24b8eee1f6c2/test_bundle.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T080316Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=4f35642010283b813b8aaf4a2e8c64d7d81c99ef1d50eb73d466cebeb1ba5493',
            ProcessResult(0, 0, 'output from curl', '')),
        Call(
            'aws devicefarm get-upload --arn arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/d73555c0-a254-48ad-b340-24b8eee1f6c2',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/d73555c0-a254-48ad-b340-24b8eee1f6c2",
                    "name": "test_bundle.zip",
                    "created": 1567929796.433,
                    "type": "APPIUM_PYTHON_TEST_PACKAGE",
                    "status": "$kUploadSucceeded",
                    "url":
                        "https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3Afake-project-id/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3Afake-project-id/d73555c0-a254-48ad-b340-24b8eee1f6c2/test_bundle.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T080802Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86399&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=225a1a89bb5440e987ec71ee850aa32527371c657cad07c341a152892a8240f2",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'aws devicefarm create-upload --project-arn $projectArn --name test_spec.yaml --type APPIUM_PYTHON_TEST_SPEC',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/34e61fe1-efc8-4e90-93fe-70eac350fa89",
                    "name": "test_spec.yaml",
                    "created": 1567930228.101,
                    "type": "APPIUM_PYTHON_TEST_SPEC",
                    "status": "INITIALIZED",
                    "url":
                        "https://prod-us-west-2-uploads-testspec.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3Afake-project-id/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3Afake-project-id/34e61fe1-efc8-4e90-93fe-70eac350fa89/test_spec.yaml?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T081028Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=2a8211babc031e13b7a66f024c444183f378a055b8a55750dd4f02c23a54375a",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'curl -T /tmp/test_sylph_run/test_spec.yaml https://prod-us-west-2-uploads-testspec.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3Afake-project-id/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3Afake-project-id/34e61fe1-efc8-4e90-93fe-70eac350fa89/test_spec.yaml?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T081028Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=2a8211babc031e13b7a66f024c444183f378a055b8a55750dd4f02c23a54375a',
            ProcessResult(0, 0, 'output from curl', '')),
        Call(
            'aws devicefarm get-upload --arn arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/34e61fe1-efc8-4e90-93fe-70eac350fa89',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/34e61fe1-efc8-4e90-93fe-70eac350fa89",
                    "name": "test_spec.yaml",
                    "created": 1567930228.101,
                    "type": "APPIUM_PYTHON_TEST_SPEC",
                    "status": "$kUploadSucceeded",
                    "url":
                        "https://prod-us-west-2-uploads-testspec.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3Afake-project-id/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3Afake-project-id/34e61fe1-efc8-4e90-93fe-70eac350fa89/test_spec.yaml?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T081214Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=d9245e947da3e053c307b0890db95062c6f875a9df503a9ec1c255fea4a3548f",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'aws devicefarm schedule-run --project-arn $projectArn --app-arn arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/94210aaa-5b94-4fe4-8535-80f2c6b8a847 --device-pool-arn arn:aws:devicefarm:us-west-2:122621792560:project:fake-project-id/eb91a358-91ae-4e0f-9e77-1c7309363b18 --name sylph run name --test testSpecArn=arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/34e61fe1-efc8-4e90-93fe-70eac350fa89,type=APPIUM_PYTHON,testPackageArn=arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/d73555c0-a254-48ad-b340-24b8eee1f6c2 --execution-configuration jobTimeoutMinutes=$jobTimeoutMinutes,accountsCleanup=false,appPackagesCleanup=false,videoCapture=true,skipAppResign=false',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "run": {"arn": "$kSuccessfulRunArn"}
                }),
                '')),
        Call(
            'aws devicefarm get-run --arn $kSuccessfulRunArn',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "run": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:run:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd",
                    "name": "sylph run 2019-08-04 16:22:02.088",
                    "type": "APPIUM_PYTHON",
                    "platform": "IOS_APP",
                    "created": 1564961135.437,
                    "status": "COMPLETED",
                    "result": "PASSED",
                    "started": 1564961135.437,
                    "stopped": 1564961841.526,
                    "counters": {
                      "total": 3,
                      "passed": 3,
                      "failed": 0,
                      "warned": 0,
                      "errored": 0,
                      "stopped": 0,
                      "skipped": 0
                    },
                    "totalJobs": 1,
                    "completedJobs": 1,
                    "billingMethod": "METERED",
                    "deviceMinutes": {
                      "total": 10.54,
                      "metered": 9.57,
                      "unmetered": 0.0
                    },
                    "appUpload":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:908d123f-af8c-4d4b-9b86-65d3d51a0e49/1122fd1e-9c78-4254-8bff-a73078a76f78",
                    "jobTimeoutMinutes": 8,
                    "devicePoolArn":
                        "arn:aws:devicefarm:us-west-2:122621792560:devicepool:908d123f-af8c-4d4b-9b86-65d3d51a0e49/fc8820b0-a783-45be-be5b-057ddba83687",
                    "radios": {
                      "wifi": true,
                      "bluetooth": false,
                      "nfc": true,
                      "gps": true
                    },
                    "skipAppResign": false,
                    "testSpecArn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:908d123f-af8c-4d4b-9b86-65d3d51a0e49/3c6772f9-98cf-4f81-aff5-87bccfee488a"
                  }
                }),
                '')),
        Call(
            'aws devicefarm list-jobs --arn $kSuccessfulRunArn',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "jobs": [
                    {
                      "arn":
                          "arn:aws:devicefarm:us-west-2:122621792560:job:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000",
                      "name": "Apple iPhone X",
                      "created": 1564961135.45,
                      "status": "COMPLETED",
                      "result": "PASSED",
                      "counters": {
                        "total": 3,
                        "passed": 3,
                        "failed": 0,
                        "warned": 0,
                        "errored": 0,
                        "stopped": 0,
                        "skipped": 0
                      },
                      "message": "Successful test lifecycle of Setup Test",
                      "device": {
                        "arn":
                            "arn:aws:devicefarm:us-west-2::device:5F1B162C265B4F34804B7D0DC2CDBE40",
                        "name": "Apple iPhone X",
                        "manufacturer": "Apple",
                        "model": "iPhone X",
                        "modelId": "A1865",
                        "formFactor": "PHONE",
                        "platform": "IOS",
                        "os": "11.4",
                        "cpu": {
                          "frequency": "Hz",
                          "architecture": "arm64",
                          "clock": 0.0
                        },
                        "resolution": {"width": 1125, "height": 2436},
                        "heapSize": 0,
                        "memory": 256000000000,
                        "image": "5F1B162C265B4F34804B7D0DC2CDBE40",
                        "remoteAccessEnabled": false,
                        "remoteDebugEnabled": false,
                        "fleetType": "PUBLIC"
                      },
                      "deviceMinutes": {
                        "total": 10.54,
                        "metered": 9.57,
                        "unmetered": 0.0
                      },
                      "videoCapture": true
                    }
                  ]
                }),
                '')),
        Call(
            'aws devicefarm list-jobs --arn $kSuccessfulRunArn',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "jobs": [
                    {
                      "arn":
                          "arn:aws:devicefarm:us-west-2:122621792560:job:fake-job-id/00000",
                      "name": "Apple iPhone X",
                      "created": 1564961135.45,
                      "status": "COMPLETED",
                      "result": "PASSED",
                      "counters": {
                        "total": 3,
                        "passed": 3,
                        "failed": 0,
                        "warned": 0,
                        "errored": 0,
                        "stopped": 0,
                        "skipped": 0
                      },
                      "message": "Successful test lifecycle of Setup Test",
                      "device": {
                        "arn":
                            "arn:aws:devicefarm:us-west-2::device:5F1B162C265B4F34804B7D0DC2CDBE40",
                        "name": "Apple iPhone X",
                        "manufacturer": "Apple",
                        "model": "iPhone X",
                        "modelId": "A1865",
                        "formFactor": "PHONE",
                        "platform": "IOS",
                        "os": "11.4",
                        "cpu": {
                          "frequency": "Hz",
                          "architecture": "arm64",
                          "clock": 0.0
                        },
                        "resolution": {"width": 1125, "height": 2436},
                        "heapSize": 0,
                        "memory": 256000000000,
                        "image": "5F1B162C265B4F34804B7D0DC2CDBE40",
                        "remoteAccessEnabled": false,
                        "remoteDebugEnabled": false,
                        "fleetType": "PUBLIC"
                      },
                      "deviceMinutes": {
                        "total": 10.54,
                        "metered": 9.57,
                        "unmetered": 0.0
                      },
                      "videoCapture": true
                    }
                  ]
                }),
                '')),
        Call(
            'aws devicefarm list-artifacts --arn arn:aws:devicefarm:us-west-2:122621792560:job:fake-job-id/00000 --type FILE',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "artifacts": [
                    {
                      "arn":
                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:fake-job-id/00000/00000/00000/00000",
                      "name": "Syslog",
                      "type": "DEVICE_LOG",
                      "extension": "syslog",
                      "url": "https://fake-url"
                    }
                  ]
                }),
                '')),
      ];

      final androidCalls = [
        Call(
            'aws devicefarm create-device-pool --name android pool 1 --project-arn arn:aws:devicefarm:us-west-2:122621792560:project:fake-project-id --rules [{"attribute": "ARN", "operator": "IN","value": "[\\"arn:aws:devicefarm:us-west-2::device:70D5B22608A149568923E4A225EC5E04\\"]"}]',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "devicePool": {
                    "arn": "$projectArn/eb91a358-91ae-4e0f-9e77-1c7309363b18",
                    "name": "ios pool xxx",
                    "type": "PRIVATE",
                    "rules":
                        "[{attribute: ARN, operator: IN, value: [\"arn:aws:devicefarm:us-west-2::device:5F1B162C265B4F34804B7D0DC2CDBE40\"]}]})"
                  }
                }),
                '')),
        Call('flutter build apk -t test_driver/main.dart --debug --flavor dev',
            ProcessResult(0, 0, 'output from build', '')),
        Call(
            'aws devicefarm create-upload --project-arn $projectArn --name app.apk --type ANDROID_APP',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/94210aaa-5b94-4fe4-8535-80f2c6b8a847",
                    "name": "app-debug.apk",
                    "created": 1567929241.253,
                    "type": "ANDROID_APP",
                    "status": "INITIALIZED",
                    "url": "https://fake-url",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call('curl -T build/app/outputs/apk/app.apk https://fake-url',
            ProcessResult(0, 0, 'output from curl', '')),
      ];

      final iosCalls = [
        Call(
            'aws devicefarm create-device-pool --name ios pool 1 --project-arn arn:aws:devicefarm:us-west-2:122621792560:project:fake-project-id --rules [{"attribute": "ARN", "operator": "IN","value": "[\\"arn:aws:devicefarm:us-west-2::device:352FDCFAA36C43AC8228DC8F23355272\\"]"}]',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "devicePool": {
                    "arn": "$projectArn/eb91a358-91ae-4e0f-9e77-1c7309363b18",
                    "name": "ios pool xxx",
                    "type": "PRIVATE",
                    "rules":
                        "[{attribute: ARN, operator: IN, value: [\"arn:aws:devicefarm:us-west-2::device:5F1B162C265B4F34804B7D0DC2CDBE40\"]}]})"
                  }
                }),
                '')),
        Call('/tmp/test_sylph_run/script/local_utils.sh --ci /',
            ProcessResult(0, 0, 'output from setting-up ci', '')),
        Call(
            '/tmp/test_sylph_run/script/local_utils.sh --build-debug-ipa --flavor dev',
            ProcessResult(0, 0, 'output from build', '')),
        Call(
            'aws devicefarm create-upload --project-arn arn:aws:devicefarm:us-west-2:122621792560:project:fake-project-id --name Debug_Runner.ipa --type IOS_APP',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:fake-project-id/94210aaa-5b94-4fe4-8535-80f2c6b8a847",
                    "name": "app-debug.apk",
                    "created": 1567929241.253,
                    "type": "ANDROID_APP",
                    "status": "INITIALIZED",
                    "url": "https://fake-url",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'curl -T build/ios/Debug-iphoneos/Debug_Runner.ipa https://fake-url',
            ProcessResult(0, 0, 'output from curl', '')),
      ];

      fakeProcessManager.calls = [
        ...startRunCalls,
        Call(
            'aws devicefarm list-device-pools --arn $projectArn --type PRIVATE',
            ProcessResult(0, 0, jsonEncode({"devicePools": []}), '')),
        listDevicesCall,
        ...androidCalls,
        ...mainRunCalls,
        Call(
            'curl https://fake-url -o /tmp/sylph_artifacts/sylph_run_name/test_sylph_run/android_pool_1/Apple_iPhone_X-A1865-11.4.0/Syslog_00000.syslog',
            null),
        Call(
            'aws devicefarm list-device-pools --arn $projectArn --type PRIVATE',
            ProcessResult(0, 0, jsonEncode({"devicePools": []}), '')),
        listDevicesCall,
        ...iosCalls,
        ...mainRunCalls,
        Call(
            'curl https://fake-url -o /tmp/sylph_artifacts/sylph_run_name/test_sylph_run/ios_pool_1/Apple_iPhone_X-A1865-11.4.0/Syslog_00000.syslog',
            null),
      ];

      final configStr = '''
        tmp_dir: $stagingDir
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
        concurrent_runs: false
        flavor: dev
        android_package_name: com.app.package
        android_app_id: com.id.dev
        project_name: $projectName
        default_job_timeout: $defaultJobTimeoutMinutes 
        device_pools:
          - pool_name: android pool 1
            pool_type: android
            devices:
              - name: Samsung Galaxy Note 4 SM-N910H
                model: SM-N910H
                os: 5.0.1
          - pool_name: ios pool 1
            pool_type: ios
            devices:
              - name: Apple iPhone 6 Plus
                model: A1522
                os: 10.0.2
        test_suites:
          - test_suite: example tests 1
            main: test_driver/main.dart
            tests:
              - test_driver/main_test.dart
            pool_names:
              - android pool 1
              - ios pool 1
            job_timeout: $jobTimeoutMinutes
      ''';

      final configFilePath = null;
      final sylphRunName = 'sylph run name';
      final sylphRunTimestamp = DateTime(1);
      final jobVerbose = true;
      final result = await sylphRun(
          configFilePath, sylphRunName, sylphRunTimestamp, jobVerbose,
          configStr: configStr);
      expect(result, isTrue);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
      FileSystem: () => fs,
      OperatingSystemUtils: () => OperatingSystemUtils(),
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'macos'
        ..environment = {
          kCIEnvVar: 'true',
          'TEAM_ID': 'team_id',
          'PUBLISHING_MATCH_CERTIFICATE_REPO':
              'PUBLISHING_MATCH_CERTIFICATE_REPO',
          'MATCH_PASSWORD': 'MATCH_PASSWORD',
          'SSH_SERVER': 'SSH_SERVER',
          'SSH_SERVER_PORT': 'SSH_SERVER_PORT',
          'AWS_ACCESS_KEY_ID': 'AWS_ACCESS_KEY_ID',
          'AWS_SECRET_ACCESS_KEY': 'AWS_SECRET_ACCESS_KEY',
        },
    });
  });

  group('concurrent run', () {
    final appDir = '.';

    FakeProcessManager fakeProcessManager;
    MemoryFileSystem fs;

    setUp(() async {
      fakeProcessManager = FakeProcessManager();
      fs = MemoryFileSystem();
      // copy app to memory file system
      copyDirFs(io.Directory('example/default_app'), fs.directory(appDir));
    });

    testUsingContext('job', () async {
      final projectName = 'test sylph run';
      final defaultJobTimeoutMinutes = '10';
      final jobTimeoutMinutes = '15';
      final stagingDir = '/tmp/test_sylph_run';

      fakeProcessManager.calls = startRunCalls;

      final configStr = '''
        tmp_dir: $stagingDir
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
        concurrent_runs: true
        project_name: $projectName
        default_job_timeout: $defaultJobTimeoutMinutes 
        device_pools:
          - pool_name: android pool 1
            pool_type: android
            devices:
              - name: Samsung Galaxy Note 4 SM-N910H
                model: SM-N910H
                os: 5.0.1
          - pool_name: ios pool 1
            pool_type: ios
            devices:
              - name: Apple iPhone 6 Plus
                model: A1522
                os: 10.0.2
        test_suites:
          - test_suite: example tests 1
            main: test_driver/main.dart
            tests:
              - test_driver/main_test.dart
            pool_names:
              - android pool 1
            job_timeout: $jobTimeoutMinutes
      ''';
      final configFilePath = null;
      final sylphRunName = 'sylph run name';
      final sylphRunTimestamp = DateTime(1);
      final jobVerbose = true;
      final result = await sylphRun(
          configFilePath, sylphRunName, sylphRunTimestamp, jobVerbose,
          configStr: configStr);
      expect(result, isTrue);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
      FileSystem: () => fs,
      OperatingSystemUtils: () => OperatingSystemUtils(),
      ConcurrentJobs: () => FakeConcurrentJobs(),
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'macos',
    });
  });

  group('run utils', () {
    MemoryFileSystem fs;

    setUp(() async {
      fs = MemoryFileSystem();
    });

    testUsingContext(
        'substitute MAIN and TESTS for actual debug main and tests', () async {
      // init setup test files in memory file system
      copyFileFs(io.File('example/flavors/sylph.yaml'), fs.directory('.'));
      final testSpecPath = './test_spec.yaml';
      final testSpecFile = fs.file(testSpecPath);
      testSpecFile.createSync();
      testSpecFile.writeAsStringSync('MAIN=xxx\nTESTS=yyy\n');

      final config = Config(configPath: './sylph.yaml');
      final test_suite = config.testSuites[0];
      final expectedMainEnvVal = test_suite.main;
      final expectedTestsEnvVal = test_suite.tests.join(",");
      final expected =
          'MAIN=$expectedMainEnvVal\nTESTS=\'$expectedTestsEnvVal\'\n';

      setTestSpecVars(test_suite, testSpecPath);
      expect(testSpecFile.readAsStringSync(), expected);
    }, overrides: <Type, Generator>{
//      Logger: () => VerboseLogger(StdoutLogger()),
      FileSystem: () => fs,
    });
  });

  group('not in context', () {
    test('sylphRuntimeFormatted', () {
      expect(
          sylphRuntimeFormatted(DateTime.now(), DateTime.now()), equals('0ms'));
    });
    test('sylphTimestamp', () {
      expect(sylphTimestamp(), isA<DateTime>());
    });
  });
}

class FakeConcurrentJobs implements ConcurrentJobs {
  @override
  Future<List<Map>> runJobs(job, List<Map> jobArgs) {
    return Future.value([
      {'result': true}
    ]);
  }
}
