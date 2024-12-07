import 'dart:io' as io;

/// A class that provides platform-specific functionality.
class Platform {
  static final Platform _instance = Platform._();
  static Platform get instance => _instance;

  Platform._();

  /// The path separator for the current platform.
  String get pathSeparator => io.Platform.pathSeparator;

  /// Whether the operating system is macOS.
  bool get isMacOS => io.Platform.isMacOS;

  /// Whether the operating system is Linux.
  bool get isLinux => io.Platform.isLinux;

  /// Whether the operating system is Windows.
  bool get isWindows => io.Platform.isWindows;

  /// The operating system's name.
  String get operatingSystem => io.Platform.operatingSystem;

  /// The path environment variable name.
  String get pathVarName => isWindows ? 'Path' : 'PATH';

  /// The environment variables for the current process.
  Map<String, String> get environment => Map<String, String>.from(io.Platform.environment);

  /// The path to the current executable.
  String get executable => io.Platform.executable;

  /// The arguments passed to the current process.
  List<String> get arguments => List<String>.from(io.Platform.arguments);

  /// The number of processors on the machine.
  int get numberOfProcessors => io.Platform.numberOfProcessors;

  /// The local hostname for the system.
  String get localHostname => io.Platform.localHostname;

  /// The operating system version.
  String get operatingSystemVersion => io.Platform.operatingSystemVersion;
}
