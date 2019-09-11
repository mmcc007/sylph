import 'dart:async';

import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:file/memory.dart';
import 'package:process/process.dart';
import 'package:sylph/src/base/concurrent_jobs.dart';
import 'package:sylph/src/device_farm.dart';
import 'package:sylph/src/resources.dart';
import 'package:sylph/src/sylph_run.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
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
  final jobTimeoutMinutes = '15';
  final projectArn =
      'arn:aws:devicefarm:us-west-2:122621792560:project:9796b48e-ad3d-4b3c-97a6-94d4e50b1792';
  final stagingDir = '/tmp/test_sylph_run';
  final appiumTemplateZip = '$stagingDir/$kAppiumTemplateZip';
  final bundleDir = '$stagingDir/$kTestBundleDir';
  final bundleZip = '$stagingDir/$kTestBundleZip';

  final startRunCalls = [
    Call(
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
            '')),
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
//        Call('chmod u+x $stagingDir/script/test_android.sh', null),
//        Call('chmod u+x $stagingDir/script/test_ios.sh', null),
//        Call('chmod u+x $stagingDir/script/local_utils.sh', null),
    Call('unzip -o -q $appiumTemplateZip -d $bundleDir', null),
//        Call('mkdir $bundleAppDir', null),
//        Call('cp -r $appDir $bundleAppDir', null),
//        Call('rm -rf $bundleAppDir/build', null),
//        Call('rm -rf $bundleAppDir/ios/Flutter/Flutter.framework', null),
//        Call('rm -rf $bundleAppDir/ios/Flutter/App.framework', null),
//        Call('cp -r $stagingDir/script $bundleAppDir', null),
//        Call('cp $stagingDir/build_to_os.txt $bundleAppDir', null),
    Call('zip -r -q $bundleZip .', null,
        sideEffects: () => fs.file(bundleZip).createSync(recursive: true)),
//        Call('stat -f%z $bundleZipName', ProcessResult(0, 0, '5000000', '')),
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
          'arn:aws:devicefarm:us-west-2:122621792560:project:9796b48e-ad3d-4b3c-97a6-94d4e50b1792';
      final stagingDir = '/tmp/test_sylph_run';
      final appiumTemplateZip = '$stagingDir/$kAppiumTemplateZip';
      final bundleDir = '$stagingDir/$kTestBundleDir';
      final bundleZip = '$stagingDir/$kTestBundleZip';
//      final bundleAppDir = '$bundleDir/$kDefaultFlutterAppName';
      final appDir = '.';

      // copy app to memory file system
      copyDirFs(io.Directory('example'), fs.directory(appDir));
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
      fakeProcessManager.calls = [
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
//        Call('chmod u+x $stagingDir/script/test_android.sh', null),
//        Call('chmod u+x $stagingDir/script/test_ios.sh', null),
//        Call('chmod u+x $stagingDir/script/local_utils.sh', null),
        Call('unzip -o -q $appiumTemplateZip -d $bundleDir', null),
//        Call('mkdir $bundleAppDir', null),
//        Call('cp -r $appDir $bundleAppDir', null),
//        Call('rm -rf $bundleAppDir/build', null),
//        Call('rm -rf $bundleAppDir/ios/Flutter/Flutter.framework', null),
//        Call('rm -rf $bundleAppDir/ios/Flutter/App.framework', null),
//        Call('cp -r $stagingDir/script $bundleAppDir', null),
//        Call('cp $stagingDir/build_to_os.txt $bundleAppDir', null),
        Call('zip -r -q $bundleZip .', null,
            sideEffects: () => fs.file(bundleZip).createSync(recursive: true)),
//        Call('stat -f%z $bundleZipName', ProcessResult(0, 0, '5000000', '')),
        Call(
            'aws devicefarm list-device-pools --arn $projectArn --type PRIVATE',
            ProcessResult(0, 0, jsonEncode({"devicePools": []}), '')),

//        Call(
//            'aws devicefarm list-device-pools --arn $projectArn --type PRIVATE',
//            ProcessResult(
//                0,
//                0,
//                jsonEncode({
//                  "devicePools": [
//                    {
//                      "arn": "$projectArn/eb91a358-91ae-4e0f-9e77-1c7309363b18",
//                      "name": "android pool 1",
//                      "type": "PRIVATE",
//                      "rules": [
//                        {
//                          "attribute": "ARN",
//                          "operator": "IN",
//                          "value":
//                              "[\"arn:aws:devicefarm:us-west-2::device:70D5B22608A149568923E4A225EC5E04\"]"
//                        }
//                      ]
//                    },
//                    {
//                      "arn": "$projectArn/eef401d8-9dc4-41d4-ac2f-d86c85c76e40",
//                      "name": "ios pool 1",
//                      "type": "PRIVATE",
//                      "rules": [
//                        {
//                          "attribute": "ARN",
//                          "operator": "IN",
//                          "value":
//                              "[\"arn:aws:devicefarm:us-west-2::device:352FDCFAA36C43AC8228DC8F23355272\"]"
//                        }
//                      ]
//                    }
//                  ]
//                }),
//                '')),
        listDevicesCall,

        Call(
            'aws devicefarm create-device-pool --name android pool 1 --project-arn arn:aws:devicefarm:us-west-2:122621792560:project:9796b48e-ad3d-4b3c-97a6-94d4e50b1792 --rules [{"attribute": "ARN", "operator": "IN","value": "[\\"arn:aws:devicefarm:us-west-2::device:70D5B22608A149568923E4A225EC5E04\\"]"}]',
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

        Call('flutter build apk -t test_driver/main.dart --debug',
            ProcessResult(0, 0, 'output from build', '')),
        Call(
            'aws devicefarm create-upload --project-arn $projectArn --name app-debug.apk --type ANDROID_APP',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/94210aaa-5b94-4fe4-8535-80f2c6b8a847",
                    "name": "app-debug.apk",
                    "created": 1567929241.253,
                    "type": "ANDROID_APP",
                    "status": "INITIALIZED",
                    "url":
                        "https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/94210aaa-5b94-4fe4-8535-80f2c6b8a847/app-debug.apk?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T075401Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=61fb88da24ce54caa7f8466c6afadb8daade120b974e05692ff3f5dfef6c76af",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'curl -T build/app/outputs/apk/debug/app-debug.apk https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/94210aaa-5b94-4fe4-8535-80f2c6b8a847/app-debug.apk?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T075401Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=61fb88da24ce54caa7f8466c6afadb8daade120b974e05692ff3f5dfef6c76af',
            ProcessResult(0, 0, 'output from curl', '')),
//        "status": "INITIALIZED",
        Call(
            'aws devicefarm get-upload --arn arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/94210aaa-5b94-4fe4-8535-80f2c6b8a847',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/94210aaa-5b94-4fe4-8535-80f2c6b8a847",
                    "name": "app-debug.apk",
                    "created": 1567929241.253,
                    "type": "ANDROID_APP",
                    "status": "$kUploadSucceeded",
                    "url":
                        "https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/94210aaa-5b94-4fe4-8535-80f2c6b8a847/app-debug.apk?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T075759Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=f1c923d76e2af320eab5149dfd8acbd178b6be56ecb654fde46d91bb461dfaef",
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
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/d73555c0-a254-48ad-b340-24b8eee1f6c2",
                    "name": "test_bundle.zip",
                    "created": 1567929796.433,
                    "type": "APPIUM_PYTHON_TEST_PACKAGE",
                    "status": "INITIALIZED",
                    "url":
                        "https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/d73555c0-a254-48ad-b340-24b8eee1f6c2/test_bundle.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T080316Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=4f35642010283b813b8aaf4a2e8c64d7d81c99ef1d50eb73d466cebeb1ba5493",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'curl -T /tmp/test_sylph_run/test_bundle.zip https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/d73555c0-a254-48ad-b340-24b8eee1f6c2/test_bundle.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T080316Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=4f35642010283b813b8aaf4a2e8c64d7d81c99ef1d50eb73d466cebeb1ba5493',
            ProcessResult(0, 0, 'output from curl', '')),
        Call(
            'aws devicefarm get-upload --arn arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/d73555c0-a254-48ad-b340-24b8eee1f6c2',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/d73555c0-a254-48ad-b340-24b8eee1f6c2",
                    "name": "test_bundle.zip",
                    "created": 1567929796.433,
                    "type": "APPIUM_PYTHON_TEST_PACKAGE",
                    "status": "$kUploadSucceeded",
                    "url":
                        "https://prod-us-west-2-uploads.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/d73555c0-a254-48ad-b340-24b8eee1f6c2/test_bundle.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T080802Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86399&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=225a1a89bb5440e987ec71ee850aa32527371c657cad07c341a152892a8240f2",
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
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/34e61fe1-efc8-4e90-93fe-70eac350fa89",
                    "name": "test_spec.yaml",
                    "created": 1567930228.101,
                    "type": "APPIUM_PYTHON_TEST_SPEC",
                    "status": "INITIALIZED",
                    "url":
                        "https://prod-us-west-2-uploads-testspec.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/34e61fe1-efc8-4e90-93fe-70eac350fa89/test_spec.yaml?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T081028Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=2a8211babc031e13b7a66f024c444183f378a055b8a55750dd4f02c23a54375a",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'curl -T /tmp/test_sylph_run/test_spec.yaml https://prod-us-west-2-uploads-testspec.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/34e61fe1-efc8-4e90-93fe-70eac350fa89/test_spec.yaml?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T081028Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=2a8211babc031e13b7a66f024c444183f378a055b8a55750dd4f02c23a54375a',
            ProcessResult(0, 0, 'output from curl', '')),
        Call(
            'aws devicefarm get-upload --arn arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/34e61fe1-efc8-4e90-93fe-70eac350fa89',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "upload": {
                    "arn":
                        "arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/34e61fe1-efc8-4e90-93fe-70eac350fa89",
                    "name": "test_spec.yaml",
                    "created": 1567930228.101,
                    "type": "APPIUM_PYTHON_TEST_SPEC",
                    "status": "$kUploadSucceeded",
                    "url":
                        "https://prod-us-west-2-uploads-testspec.s3-us-west-2.amazonaws.com/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aproject%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/uploads/arn%3Aaws%3Adevicefarm%3Aus-west-2%3A122621792560%3Aupload%3A9796b48e-ad3d-4b3c-97a6-94d4e50b1792/34e61fe1-efc8-4e90-93fe-70eac350fa89/test_spec.yaml?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T081214Z&X-Amz-SignedHeaders=host&X-Amz-Expires=86400&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=d9245e947da3e053c307b0890db95062c6f875a9df503a9ec1c255fea4a3548f",
                    "category": "PRIVATE"
                  }
                }),
                '')),
        Call(
            'aws devicefarm schedule-run --project-arn arn:aws:devicefarm:us-west-2:122621792560:project:9796b48e-ad3d-4b3c-97a6-94d4e50b1792 --app-arn arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/94210aaa-5b94-4fe4-8535-80f2c6b8a847 --device-pool-arn arn:aws:devicefarm:us-west-2:122621792560:project:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/eb91a358-91ae-4e0f-9e77-1c7309363b18 --name sylph run name --test testSpecArn=arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/34e61fe1-efc8-4e90-93fe-70eac350fa89,type=APPIUM_PYTHON,testPackageArn=arn:aws:devicefarm:us-west-2:122621792560:upload:9796b48e-ad3d-4b3c-97a6-94d4e50b1792/d73555c0-a254-48ad-b340-24b8eee1f6c2 --execution-configuration jobTimeoutMinutes=$jobTimeoutMinutes,accountsCleanup=false,appPackagesCleanup=false,videoCapture=true,skipAppResign=false',
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
            'aws devicefarm list-artifacts --arn arn:aws:devicefarm:us-west-2:122621792560:job:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000 --type FILE',
            ProcessResult(
                0,
                0,
                jsonEncode({
                  "artifacts": [
                    {
                      "arn":
                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00000/00000/00000",
                      "name": "Syslog",
                      "type": "DEVICE_LOG",
                      "extension": "syslog",
                      "url":
                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00000/00000/2caf5715-3f3b-4dc3-bd7a-744d16759e37.syslog?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=97ec48885b4bad3fb8bcd878d5fcaec03df2e53a08e6243156831f0c6b5b3578"
                    }
//                    ,
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00000/00000/00002",
//                      "name": "TCP dump log",
//                      "type": "RAW_FILE",
//                      "extension": "txt",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00000/00000/4a37048f-021e-4429-aed7-eff873f73645.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259199&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=bf39dcc88cc307a7640ad51848f9f012445a97bcb9cc2996dccb42b4e4050d7a"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/00000",
//                      "name": "Test spec output",
//                      "type": "TESTSPEC_OUTPUT",
//                      "extension": "txt",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/72cf2028-47e7-4103-9988-30f2744fb0e8.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=b79ef10f75ce4eae1960b4c7b3db5dc20f3ea56c34c4eefbf352eb09b54a6739"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/00001",
//                      "name": "Test spec shell script",
//                      "type": "RAW_FILE",
//                      "extension": "sh",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/f9bb50ec-7ccf-4fc1-b683-8c480c8e8b50.sh?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=1d29fcc4f0deaa58160876e3326a6e0f6405b09ecf07485276ec2169cee557f7"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/00002",
//                      "name": "Test spec file",
//                      "type": "RAW_FILE",
//                      "extension": "yml",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/c26f508b-40d2-4294-9977-bcd8fa1eed8a.yml?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=ba9a41801ad4fa2652acab62a8a0c28d66fc5e24a95796037735f81a239b28bb"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/00003",
//                      "name": "Customer Artifacts Log",
//                      "type": "CUSTOMER_ARTIFACT_LOG",
//                      "extension": "txt",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/ccc6cf7c-6309-4bdc-9cc3-cb90eff61a9c.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=faffbb72e85f10f2f5df6815df2e747c342c044d8e0415e3705b672e20439721"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/00004",
//                      "name": "Video",
//                      "type": "VIDEO",
//                      "extension": "mp4",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/2a40b95d-af30-40aa-89de-5de67c08d9f8.mp4?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=3590ab262da32f72dcee618353819b7ea9666d5155d51933d87ddccf4ff11c40"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/00005",
//                      "name": "Syslog",
//                      "type": "DEVICE_LOG",
//                      "extension": "syslog",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/23b06c69-2166-40de-85e9-ef15939a4aba.syslog?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=6ed3b4c38f4dd9673d54ba6f320b4cb9dfe139bc0faa468dd556d3d31e09240e"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/00007",
//                      "name": "TCP dump log",
//                      "type": "RAW_FILE",
//                      "extension": "txt",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00001/00000/a8560255-4cb6-421d-8d41-83e046b7818c.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=b327c6e1bceb5170e2b79d5bc57b51028a4c900999e94e3a1365a78cf5b30b7a"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00002/00000/00000",
//                      "name": "Webkit Log",
//                      "type": "WEBKIT_LOG",
//                      "extension": "webkitlog",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00002/00000/7811daa6-1897-48b7-9722-5e25581db6f7.webkitlog?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=d33153c5be4d18ef41abb6451a5824e971e0d451da6e031b993816b06b93efb9"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00002/00000/00001",
//                      "name": "Syslog",
//                      "type": "DEVICE_LOG",
//                      "extension": "syslog",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00002/00000/cc5f92f5-7473-4514-9274-f03ae7821001.syslog?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=3139f1a71ed5f6d90a054e4863f5e25c038be8572e92f156e74a47cca9cb1be6"
//                    },
//                    {
//                      "arn":
//                          "arn:aws:devicefarm:us-west-2:122621792560:artifact:908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00002/00000/00003",
//                      "name": "TCP dump log",
//                      "type": "RAW_FILE",
//                      "extension": "txt",
//                      "url":
//                          "https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00002/00000/0058f5f1-5b68-4029-976c-33dda6bbb7c0.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=362bbc5c8448fa70f4b4fddbfffe2277fb14f4c5c7d457c10c29fa18cb7903a4"
//                    }
                  ]
                }),
                '')),
        Call(
            'curl https://prod-us-west-2-results.s3-us-west-2.amazonaws.com/122621792560/908d123f-af8c-4d4b-9b86-65d3d51a0e49/5f484a00-5399-40ee-aae8-2d65196a5bcd/00000/00000/00000/2caf5715-3f3b-4dc3-bd7a-744d16759e37.syslog?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20190908T090151Z&X-Amz-SignedHeaders=host&X-Amz-Expires=259200&X-Amz-Credential=AKIAJSORV74ENYFBITRQ%2F20190908%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Signature=97ec48885b4bad3fb8bcd878d5fcaec03df2e53a08e6243156831f0c6b5b3578 -o /tmp/sylph_artifacts/sylph_run_name/test_sylph_run/android_pool_1/Apple_iPhone_X-A1865-11.4.0/Syslog_00000.syslog',
            null),
      ];

      final configStr = '''
        tmp_dir: $stagingDir
        artifacts_dir: /tmp/sylph_artifacts
        sylph_timeout: 720 
        concurrent_runs: false
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
//      - ios pool 1

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
      copyDirFs(io.Directory('example'), fs.directory(appDir));
    });

    testUsingContext('job', () async {
      final projectName = 'test sylph run';
      final defaultJobTimeoutMinutes = '10';
      final jobTimeoutMinutes = '15';
      final stagingDir = '/tmp/test_sylph_run';

      fakeProcessManager.calls = [...startRunCalls];

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
