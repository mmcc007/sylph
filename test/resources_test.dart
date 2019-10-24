import 'package:sylph/src/resources.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

main() {
  group('resources', () {
    group('in context', () {
      testUsingContext('unpack all', () async {
        final stagingDir = '/tmp/sylph_test_unpack';
        // note: expects certain env vars to be defined
        await unpackResources(stagingDir, true, appDir: 'example/default_app');
        expect(fs.file('$stagingDir/$kAppiumTemplateZip').existsSync(), isTrue);
      }, overrides: <Type, Generator>{
        Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
          ..environment = {kCIEnvVar: 'true', 'TEAM_ID': 'team_id'},
//        Logger: () => VerboseLogger(StdoutLogger()),
      });
    });

    group('unpack some resources', () {
      test('unpack a file', () async {
        final srcPath = 'Gemfile';
        final dstDir = '/tmp/test_unpack_file';
        await unpackFile(srcPath, dstDir);
        final dstPath = '$dstDir/$srcPath';
        expect(fs.file(dstPath).existsSync(), isTrue,
            reason: '$dstPath does not exist');
      });

      testUsingContext('substitute env vars in string', () {
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
      }, overrides: <Type, Generator>{
        Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
          ..environment = {kCIEnvVar: 'true', 'TEAM_ID': 'team_id'},
//        Logger: () => VerboseLogger(StdoutLogger()),
      });

      testUsingContext('unpack files with env vars and name/value pairs',
          () async {
        final envVars = ['TEAM_ID'];
        final filePaths = ['fastlane/Appfile', 'exportOptions.plist'];
        final dstDir = '/tmp/test_env_files';
        final nameVals = {
          kAppIdentifier: getAppIdentifier('example/default_app')
        };

        for (final srcPath in filePaths) {
          await unpackFile(srcPath, dstDir,
              envVars: envVars, nameVals: nameVals);
          final dstPath = '$dstDir/$srcPath';
          expect(fs.file(dstPath).existsSync(), isTrue,
              reason: '$dstPath not found');
        }
      }, overrides: <Type, Generator>{
        Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
          ..environment = {kCIEnvVar: 'true', 'TEAM_ID': 'team_id'},
//        Logger: () => VerboseLogger(StdoutLogger()),
      });

      test('find APP_IDENTIFIER', () {
        final expected = 'com.orbsoft.counter';
        String appIdentifier = getAppIdentifier('example/default_app');
        expect(appIdentifier, expected);
      });
    });
  });
}
