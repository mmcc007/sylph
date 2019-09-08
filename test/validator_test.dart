import 'package:sylph/src/validator.dart';
import 'package:test/test.dart';
import 'package:tool_base_test/tool_base_test.dart';
import 'package:yaml/yaml.dart';

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
      Map config = loadYaml(goodConfigStr);
      expect(isValidPoolTypes(config['device_pools']), isTrue);
      final badConfigStr = '''
      device_pools:
        - pool_name: android pool 1
          pool_type: android
        - pool_name: ios pool 1
          pool_type: iosx
        - pool_name: ios pool 2
          pool_type: ios
      ''';
      config = loadYaml(badConfigStr);
      expect(isValidPoolTypes(config['device_pools']), isFalse);
    });
  });
}
