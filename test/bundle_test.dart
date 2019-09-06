import 'package:sylph/src/utils.dart';
import 'package:test/test.dart';

main() {
  group('bundle', () {
    test('flutter', () {
      final flutterVersion = '1.7.8+hotfix.4';
      // download zip for mac and linux to staging are and include in bundle
      // unzip and install on device farm
      Map config = await parseYamlFile(configFilePath);
    });
  });
}
