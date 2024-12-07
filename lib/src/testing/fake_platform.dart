import '../utils/platform.dart';

/// A fake platform for testing.
class FakePlatform extends Platform {
  FakePlatform({
    this.isLinuxValue = false,
    this.isMacOSValue = true,
    this.isWindowsValue = false,
    this.operatingSystemValue = 'macos',
    this.pathSeparatorValue = '/',
    this.pathVarNameValue = 'PATH',
    this.environmentValue = const <String, String>{},
    this.executableValue = '/usr/bin/dart',
    this.argumentsValue = const <String>[],
    this.numberOfProcessorsValue = 8,
    this.localHostnameValue = 'localhost',
    this.operatingSystemVersionValue = '10.15.7',
  });

  final bool isLinuxValue;
  final bool isMacOSValue;
  final bool isWindowsValue;
  final String operatingSystemValue;
  final String pathSeparatorValue;
  final String pathVarNameValue;
  final Map<String, String> environmentValue;
  final String executableValue;
  final List<String> argumentsValue;
  final int numberOfProcessorsValue;
  final String localHostnameValue;
  final String operatingSystemVersionValue;

  @override
  bool get isLinux => isLinuxValue;

  @override
  bool get isMacOS => isMacOSValue;

  @override
  bool get isWindows => isWindowsValue;

  @override
  String get operatingSystem => operatingSystemValue;

  @override
  String get pathSeparator => pathSeparatorValue;

  @override
  String get pathVarName => pathVarNameValue;

  @override
  Map<String, String> get environment => Map<String, String>.from(environmentValue);

  @override
  String get executable => executableValue;

  @override
  List<String> get arguments => List<String>.from(argumentsValue);

  @override
  int get numberOfProcessors => numberOfProcessorsValue;

  @override
  String get localHostname => localHostnameValue;

  @override
  String get operatingSystemVersion => operatingSystemVersionValue;
}
