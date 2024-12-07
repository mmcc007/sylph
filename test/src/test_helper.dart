import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sylph/src/testing/testing.dart';
import 'package:sylph/src/utils/utils.dart';

/// Creates a test environment with fake platform, file system, and process manager.
class TestEnvironment {
  final FakeFileSystem fs;
  final FakePlatform platform;
  final FakeProcessManager processManager;

  TestEnvironment({
    FakeFileSystem? fs,
    FakePlatform? platform,
    FakeProcessManager? processManager,
  })  : fs = fs ?? FakeFileSystem(),
        platform = platform ?? FakePlatform(),
        processManager = processManager ?? FakeProcessManager();

  /// Get the test context overrides.
  Map<Type, dynamic> get overrides => {
        FileSystem: fs,
        Platform: platform,
        ProcessManager: processManager,
      };

  /// Create a temporary directory for testing.
  String createTempDir(String name) {
    final tempDir = p.join(Directory.systemTemp.path, 'sylph_test', name);
    fs.createDirectory(tempDir, recursive: true);
    return tempDir;
  }

  /// Create a test file with content.
  void createTestFile(String path, String content) {
    final dir = p.dirname(path);
    fs.createDirectory(dir, recursive: true);
    fs.writeFileAsString(path, content);
  }

  /// Add a fake AWS command result.
  void addAwsResult(List<String> args, {
    required Map<String, dynamic> response,
    String stderr = '',
    int exitCode = 0,
  }) {
    processManager.addFakeResult(
      ProcessCall('aws', args, null),
      ProcessResult(0, exitCode, jsonEncode(response), stderr),
    );
  }

  /// Clear all fake resources.
  void clear() {
    fs.clear();
    processManager.processCallLog.clear();
  }
}
