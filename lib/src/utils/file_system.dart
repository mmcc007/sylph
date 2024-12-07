import 'dart:io';
import 'package:path/path.dart' as path;

/// Recursively create a directory and all its parent directories if they don't exist.
Directory ensureDirectoryExists(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir;
}

/// Delete a directory and all its contents if it exists.
void deleteDirectoryIfExists(String dirPath) {
  final dir = Directory(dirPath);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

/// Copy a file to a new location, creating parent directories if needed.
void copyFile(String sourcePath, String targetPath) {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw FileSystemException('Source file does not exist', sourcePath);
  }
  
  final targetFile = File(targetPath);
  ensureDirectoryExists(path.dirname(targetPath));
  sourceFile.copySync(targetPath);
}

/// Copy a directory and its contents to a new location.
void copyDirectory(String sourcePath, String targetPath) {
  final sourceDir = Directory(sourcePath);
  if (!sourceDir.existsSync()) {
    throw FileSystemException('Source directory does not exist', sourcePath);
  }

  final targetDir = Directory(targetPath);
  ensureDirectoryExists(targetPath);

  for (final entity in sourceDir.listSync(recursive: true)) {
    final sourceFilePath = entity.path;
    final relativeFilePath = path.relative(sourceFilePath, from: sourcePath);
    final targetFilePath = path.join(targetPath, relativeFilePath);

    if (entity is File) {
      copyFile(sourceFilePath, targetFilePath);
    } else if (entity is Directory) {
      ensureDirectoryExists(targetFilePath);
    }
  }
}
