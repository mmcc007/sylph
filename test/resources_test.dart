import 'package:sylph/src/resources.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

main() {
  group('resources', () {
    group('unpack resources', () {
      test('unpack a file', () async {
        final srcPath = 'exportOptions.plist';
        final dstDir = '/tmp/test_unpack_file';
        await unpackFile(srcPath, dstDir);
        final dstPath = '$dstDir/$srcPath';
        expect(fs.file(dstPath).existsSync(), isTrue,
            reason: '$dstPath does not exist');
      });

      test('substitute env vars in string', () {
        final env = platform.environment;
        final envVars = ['TEAM_ID'];
        final expected = () {
          final envs = [];
          for (final envVar in envVars) {
            final envVal = env[envVar];
            expect(envVal, isNotNull);
            envs.add(envVal);
          }
          return envs.join(',');
        };
        String str = envVars.join(',');
        for (final envVar in envVars) {
          str = str.replaceAll(envVar, env[envVar]);
        }
        expect(str, expected());
      });

      test('unpack files with env vars and name/value pairs', () async {
        final envVars = ['TEAM_ID'];
        final filePaths = ['fastlane/Appfile', 'exportOptions.plist'];
        final dstDir = '/tmp/test_env_files';

        // change directory to app to get to ios dir
        final origDir = fs.currentDirectory;
        fs.currentDirectory = 'example';
        final nameVals = {kAppIdentifier: getAppIdentifier()};
        // change back for tests to continue
        fs.currentDirectory = origDir;

        for (final srcPath in filePaths) {
          await unpackFile(srcPath, dstDir,
              envVars: envVars, nameVals: nameVals);
          final dstPath = '$dstDir/$srcPath';
          expect(fs.file(dstPath).existsSync(), isTrue,
              reason: '$dstPath not found');
        }
      });

      test('find APP_IDENTIFIER', () {
        final expected = 'com.orbsoft.counter';
        // change directory to app
        final origDir = fs.currentDirectory;
        fs.currentDirectory = 'example';

        String appIdentifier = getAppIdentifier();
        expect(appIdentifier, expected);

        // change back for tests to continue
        fs.currentDirectory = origDir;
      });
    });
  });
}
