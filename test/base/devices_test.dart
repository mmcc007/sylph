import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:process/process.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/src/base/devices.dart';
import 'package:sylph/src/device_farm.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart' hide Config;
import 'package:tool_base_test/tool_base_test.dart';
import 'package:version/version.dart' as v;

main() {
  group('devices', () {
    group('device equality', () {
      test('test for equality between sylph devices', () {
        final name1 = 'name1';
        final name2 = 'name2';
        final model = 'model';
        final os = v.Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final sylphDevice1 = SylphDevice(name1, model, os, deviceType);
        final sylphDevice2 = SylphDevice(name2, model, os, deviceType);
        expect(sylphDevice1 == Object(), isFalse);
        expect(sylphDevice1 == sylphDevice1, isTrue);
        expect(sylphDevice1 == sylphDevice2, isFalse);
      });

      test('test for equality between device farm devices', () {
        final formFactor = FormFactor.phone;
        final arn1 = 'arn1';
        final arn2 = 'arn2';
        final availability = 'availability';
        final name = 'name';
        final model = 'model';
        final os = v.Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final deviceFarmDevice1 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor, availability, arn1);
        final deviceFarmDevice2 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor, availability, arn2);
        expect(deviceFarmDevice1 == Object(), isFalse);
        expect(deviceFarmDevice1 == deviceFarmDevice1, isTrue);
        expect(deviceFarmDevice1 == deviceFarmDevice2, isFalse);
      });

      test('test for equality between SylphDevice and DeviceFarmDevice classes',
          () {
        final name = 'name';
        final model = 'model';
        final os = v.Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final sylphDevice = SylphDevice(name, model, os, deviceType);
        final formFactor = FormFactor.phone;
        final availability = 'availability';
        final arn = 'arn';
        final deviceFarmDevice = DeviceFarmDevice(
            name, model, os, deviceType, formFactor, availability, arn);
        expect(deviceFarmDevice == sylphDevice,
            isTrue); // uses DeviceFarmDevice ==
        expect(sylphDevice == deviceFarmDevice, isTrue); // uses SylphDevice ==

        // device farm device has a different value for a shared member
        final deviceFarmDeviceDiffSharedMember = DeviceFarmDevice(
            'device farm name',
            model,
            os,
            deviceType,
            formFactor,
            availability,
            arn);
        expect(deviceFarmDeviceDiffSharedMember == sylphDevice, isFalse);
        expect(sylphDevice == deviceFarmDeviceDiffSharedMember, isFalse);

        // device farm device has a different value for a unique member
        final deviceFarmDeviceDiffUniqueMember = DeviceFarmDevice(name, model,
            os, deviceType, formFactor, availability, 'device farm arn');
        expect(deviceFarmDeviceDiffUniqueMember == sylphDevice, isTrue);
        expect(sylphDevice == deviceFarmDeviceDiffUniqueMember, isTrue);
      });
    });

    const kOrderedBefore = -1;
    group('device sorting', () {
      test('sort sylph devices', () {
        final name1 = 'name1';
        final name2 = 'name2';
        final model = 'model';
        final os = v.Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final sylphDevice1 = SylphDevice(name1, model, os, deviceType);
        final sylphDevice2 = SylphDevice(name2, model, os, deviceType);
        expect(sylphDevice1.compareTo(sylphDevice2), kOrderedBefore);
      });

      test('sort device farm devices', () {
        final name = 'name';
        final model = 'model';
        final os = v.Version.parse('1.2.3');
        final deviceType = DeviceType.android;
        final formFactor1 = FormFactor.phone;
        final formFactor2 = FormFactor.tablet;
        final availability = 'availability';
        final arn = 'arn';
        final dfDev1 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor1, availability, arn);
        final dfDevice2 = DeviceFarmDevice(
            name, model, os, deviceType, formFactor2, availability, arn);
        expect(dfDev1.compareTo(dfDevice2), kOrderedBefore);
      });
    });

    group('sylph devices', () {
      test('get sylph devices from config file', () async {
        final configPath = 'test/sylph_test.yaml';
        final config = Config(configPath: configPath);
        final poolName = 'android pool 1';
        final devicePool = config.getDevicePool(poolName);
        final expectedFirstDeviceName = devicePool.devices[0].name;
        final expectedDeviceCount = devicePool.devices.length;
        final sylphDevices = devicePool.devices;
        expect(sylphDevices[0].name, expectedFirstDeviceName);
        expect(sylphDevices.length, expectedDeviceCount);
        // check sorting
        expect(sylphDevices[0].compareTo(sylphDevices[1]), kOrderedBefore);
      });
    });

    group('device farm devices', () {
      final calls = [
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
      ];
      FakeProcessManager fakeProcessManager;

      setUp(() async {
        fakeProcessManager = FakeProcessManager();
      });

      testUsingContext('compare device farm devices', () async {
        fakeProcessManager.calls = calls;
        final deviceFarmDevices = getDeviceFarmDevices();
        expect(deviceFarmDevices[0].compareTo(deviceFarmDevices[1]),
            kOrderedBefore);
        expect(deviceFarmDevices.length, equals(2));
        fakeProcessManager.verifyCalls();
      }, overrides: <Type, Generator>{
        ProcessManager: () => fakeProcessManager,
      });

      testUsingContext('get all device farm devices', () {
        fakeProcessManager.calls = calls;
        final List<DeviceFarmDevice> deviceFarmDevices = getDeviceFarmDevices();
        expect(deviceFarmDevices.length, equals(2));
        fakeProcessManager.verifyCalls();
      }, overrides: <Type, Generator>{
        ProcessManager: () => fakeProcessManager,
      });

      testUsingContext('get device farm android devices', () {
        fakeProcessManager.calls = calls;
        final List<DeviceFarmDevice> androidDevices =
            getDeviceFarmDevicesByType(DeviceType.android);
        expect(androidDevices.length, equals(1));
        fakeProcessManager.verifyCalls();
      }, overrides: <Type, Generator>{
        ProcessManager: () => fakeProcessManager,
      });

      testUsingContext('get device farm ios devices', () {
        fakeProcessManager.calls = calls;
        final List<DeviceFarmDevice> iOSDevices =
            getDeviceFarmDevicesByType(DeviceType.ios);
        expect(iOSDevices.length, equals(1));
        fakeProcessManager.verifyCalls();
      }, overrides: <Type, Generator>{
        ProcessManager: () => fakeProcessManager,
      });
    });
  });
}
