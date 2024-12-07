import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// A fake file system for testing.
class FakeFileSystem {
  final Map<String, dynamic> _files = {};
  final List<String> _createdDirectories = [];

  /// Create a file with the given content.
  void file(String path, String content) {
    _files[_normalize(path)] = content;
  }

  /// Create a directory.
  void directory(String path) {
    _createdDirectories.add(_normalize(path));
  }

  /// Check if a file exists.
  bool fileExists(String path) {
    return _files.containsKey(_normalize(path));
  }

  /// Check if a directory exists.
  bool directoryExists(String path) {
    final normalized = _normalize(path);
    return _createdDirectories.any((dir) => normalized.startsWith(dir));
  }

  /// Read a file as a string.
  String readFileAsString(String path) {
    final normalized = _normalize(path);
    if (!fileExists(normalized)) {
      throw FileSystemException('File not found', path);
    }
    return _files[normalized] as String;
  }

  /// Read a file as bytes.
  List<int> readFileAsBytes(String path) {
    return utf8.encode(readFileAsString(path));
  }

  /// Write a file.
  void writeFileAsString(String path, String content) {
    _files[_normalize(path)] = content;
  }

  /// Write a file with bytes.
  void writeFileAsBytes(String path, List<int> bytes) {
    writeFileAsString(path, utf8.decode(bytes));
  }

  /// Create a directory.
  void createDirectory(String path, {bool recursive = false}) {
    final normalized = _normalize(path);
    if (recursive) {
      var current = '';
      for (final part in normalized.split('/')) {
        if (part.isEmpty) continue;
        current = p.join(current, part);
        if (!directoryExists(current)) {
          directory(current);
        }
      }
    } else {
      directory(normalized);
    }
  }

  /// Delete a file.
  void deleteFile(String path) {
    _files.remove(_normalize(path));
  }

  /// Delete a directory.
  void deleteDirectory(String path, {bool recursive = false}) {
    final normalized = _normalize(path);
    _createdDirectories.removeWhere((dir) => dir == normalized);
    if (recursive) {
      _files.removeWhere((key, _) => key.startsWith(normalized));
      _createdDirectories.removeWhere((dir) => dir.startsWith(normalized));
    }
  }

  /// List the contents of a directory.
  List<String> listDirectory(String path) {
    final normalized = _normalize(path);
    final result = <String>{};

    // Add files
    for (final file in _files.keys) {
      if (p.dirname(file) == normalized) {
        result.add(file);
      }
    }

    // Add directories
    for (final dir in _createdDirectories) {
      if (p.dirname(dir) == normalized) {
        result.add(dir);
      }
    }

    return result.toList();
  }

  String _normalize(String path) {
    return p.normalize(path).replaceAll(r'\', '/');
  }

  /// Clear all files and directories.
  void clear() {
    _files.clear();
    _createdDirectories.clear();
  }
}
