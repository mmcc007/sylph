import 'package:sylph/src/config.dart';
import 'package:sylph/src/devices.dart';
import 'package:sylph/src/utils.dart';
import 'package:test/test.dart';

main() {
  group('android only runs', () {
    test('is pool type active', () async {
      final configPath = 'test/sylph_test.yaml';
      final config = await parseYamlFile(configPath);
      final androidPoolType = DeviceType.android;

      bool isAndroidActive = isPoolTypeActive(config, androidPoolType);

      expect(isAndroidActive, isTrue);
    });
  });
}
