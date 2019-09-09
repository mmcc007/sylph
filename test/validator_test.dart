import 'package:sylph/src/config.dart';
import 'package:test/test.dart';
import 'package:tool_base_test/tool_base_test.dart';

main() {
  group('validator', () {
    testUsingContext('check for valid pool types', () {
      final goodConfigStr = '''
      device_pools:
        - pool_name: android pool 1
          pool_type: android
        - pool_name: ios pool 1
          pool_type: ios
        - pool_name: ios pool 2
          pool_type: ios
      ''';
      Config config = Config(configStr: goodConfigStr);
      expect(config.isValidPoolTypes(), isTrue);
      final badConfigStr = '''
      device_pools:
        - pool_name: android pool 1
          pool_type: android
        - pool_name: ios pool 1
          pool_type: iosx
        - pool_name: ios pool 2
          pool_type: ios
      ''';
      config = Config(configStr: badConfigStr);
      expect(config.isValidPoolTypes(), isFalse);
    });
  });
}
