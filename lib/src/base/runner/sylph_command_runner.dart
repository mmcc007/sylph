// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:completion/completion.dart';
import 'package:file/file.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:reporting/reporting.dart';
import 'package:sylph/runner.dart';
import 'package:sylph/src/base/user_messages.dart';
import 'package:tool_base/tool_base.dart';

//import '../base/flags.dart';
//import '../base/io.dart' as io;
//import '../base/logger.dart';
//import '../base/os.dart';
//import '../base/platform.dart';
//import '../base/process.dart';
//import '../base/process_manager.dart';
//import '../base/terminal.dart';
//import '../base/user_messages.dart';
//import '../base/utils.dart';
//import '../cache.dart';
//import '../convert.dart';
//import '../dart/package_map.dart';
//import '../device.dart';
//import '../globals.dart';
//import '../reporting/reporting.dart';
//import '../tester/flutter_tester.dart';import '../artifacts.dart';
//import '../base/common.dart';
//import '../base/context.dart';
//import '../base/file_system.dart';

import '../version.dart';
//import '../vmservice.dart';

const String kFlutterRootEnvironmentVariableName = 'SYLPH_ROOT'; // should point to //flutter/ (root of flutter/flutter repo)
//const String kFlutterEngineEnvironmentVariableName = 'FLUTTER_ENGINE'; // should point to //engine/src/ (root of flutter/engine repo)
//const String kSnapshotFileName = 'flutter_tools.snapshot'; // in //flutter/bin/cache/
//const String kFlutterToolsScriptFileName = 'flutter_tools.dart'; // in //flutter/packages/flutter_tools/bin/
//const String kFlutterEnginePackageName = 'sky_engine';

class SylphCommandRunner extends CommandRunner<void> {
  SylphCommandRunner({ bool verboseHelp = false }) : super(
    'sylph',
    'Runs Flutter integration tests on real devices in cloud.\n'
        '\n'
        'Common commands:\n'
        '\n'
        '  sylph devices [options]\n'
        '    Get a list of currently available devices.\n'
        '\n'
        '  sylph run [options]\n'
        '    Run Flutter integration tests on pools of devices in cloud.',
  ) {
    argParser.addFlag('verbose',
        abbr: 'v',
        negatable: false,
        help: 'Noisy logging, including all shell commands executed.\n'
            'If used with --help, shows hidden options.');
    argParser.addFlag('quiet',
        negatable: false,
        hide: !verboseHelp,
        help: 'Reduce the amount of output from some commands.');
    argParser.addFlag('wrap',
        negatable: true,
        hide: !verboseHelp,
        help: 'Toggles output word wrapping, regardless of whether or not the output is a terminal.',
        defaultsTo: true);
    argParser.addOption('wrap-column',
        hide: !verboseHelp,
        help: 'Sets the output wrap column. If not set, uses the width of the terminal. No '
            'wrapping occurs if not writing to a terminal. Use --no-wrap to turn off wrapping '
            'when connected to a terminal.',
        defaultsTo: null);
//    argParser.addOption('device-id',
//        abbr: 'd',
//        help: 'Target device id or name (prefixes allowed).');
    argParser.addFlag('version',
        negatable: false,
        help: 'Reports the version of this tool.');
    argParser.addFlag('machine',
        negatable: false,
        hide: !verboseHelp,
        help: 'When used with the --version flag, outputs the information using JSON.');
    argParser.addFlag('color',
        negatable: true,
        hide: !verboseHelp,
        help: 'Whether to use terminal colors (requires support for ANSI escape sequences).',
        defaultsTo: true);
    argParser.addFlag('version-check',
        negatable: true,
        defaultsTo: true,
        hide: !verboseHelp,
        help: 'Allow Sylph to check for updates when this command runs.');
    argParser.addFlag('suppress-analytics',
        negatable: false,
        help: 'Suppress analytics reporting when this command runs.');
    argParser.addFlag('bug-report',
        negatable: false,
        help: 'Captures a bug report file to submit to the Sylph team.\n'
            'Contains local paths, device identifiers, and log snippets.');

//    String packagesHelp;
//    bool showPackagesCommand;
//    if (fs.isFileSync(kPackagesFileName)) {
//      packagesHelp = '(defaults to "$kPackagesFileName")';
//      showPackagesCommand = verboseHelp;
//    } else {
//      packagesHelp = '(required, since the current directory does not contain a "$kPackagesFileName" file)';
//      showPackagesCommand = true;
//    }
//    argParser.addOption('packages',
//        hide: !showPackagesCommand,
//        help: 'Path to your ".packages" file.\n$packagesHelp');
//
//    argParser.addOption('flutter-root',
//        hide: !verboseHelp,
//        help: 'The root directory of the Flutter repository.\n'
//            'Defaults to \$$kFlutterRootEnvironmentVariableName if set, otherwise uses the parent '
//            'of the directory that the "flutter" script itself is in.');

    if (verboseHelp)
      argParser.addSeparator('Local build selection options (not normally required):');

//    argParser.addOption('local-engine-src-path',
//        hide: !verboseHelp,
//        help: 'Path to your engine src directory, if you are building Flutter locally.\n'
//            'Defaults to \$$kFlutterEngineEnvironmentVariableName if set, otherwise defaults to '
//            'the path given in your pubspec.yaml dependency_overrides for $kFlutterEnginePackageName, '
//            'if any, or, failing that, tries to guess at the location based on the value of the '
//            '--flutter-root option.');
//
//    argParser.addOption('local-engine',
//        hide: !verboseHelp,
//        help: 'Name of a build output within the engine out directory, if you are building Flutter locally.\n'
//            'Use this to select a specific version of the engine if you have built multiple engine targets.\n'
//            'This path is relative to --local-engine-src-path/out.');

    if (verboseHelp)
      argParser.addSeparator('Options for testing the "sylph" tool itself:');

    argParser.addOption('record-to',
        hide: !verboseHelp,
        help: 'Enables recording of process invocations (including stdout and stderr of all such invocations), '
            'and file system access (reads and writes).\n'
            'Serializes that recording to a directory with the path specified in this flag. If the '
            'directory does not already exist, it will be created.');
    argParser.addOption('replay-from',
        hide: !verboseHelp,
        help: 'Enables mocking of process invocations by replaying their stdout, stderr, and exit code from '
            'the specified recording (obtained via --record-to). The path specified in this flag must refer '
            'to a directory that holds serialized process invocations structured according to the output of '
            '--record-to.');
//    argParser.addFlag('show-test-device',
//        negatable: false,
//        hide: !verboseHelp,
//        help: 'List the special \'flutter-tester\' device in device listings. '
//            'This headless device is used to\ntest Flutter tooling.');
  }

  @override
  ArgParser get argParser => _argParser;
  final ArgParser _argParser = ArgParser(
    allowTrailingOptions: false,
    usageLineLength: outputPreferences.wrapText ? outputPreferences.wrapColumn : null,
  );

  @override
  String get usageFooter {
    return wrapText('Run "sylph help -v" for verbose help output, including less commonly used options.');
  }

  @override
  String get usage {
    final String usageWithoutDescription = super.usage.substring(description.length + 2);
    return  '${wrapText(description)}\n\n$usageWithoutDescription';
  }

  static String get defaultFlutterRoot {
    if (platform.environment.containsKey(kFlutterRootEnvironmentVariableName))
      return platform.environment[kFlutterRootEnvironmentVariableName];
//    try {
//      if (platform.script.scheme == 'data')
//        return '../..'; // we're running as a test
//
//      if (platform.script.scheme == 'package') {
//        final String packageConfigPath = Uri.parse(platform.packageConfig).toFilePath();
//        return fs.path.dirname(fs.path.dirname(fs.path.dirname(packageConfigPath)));
//      }
//
//      final String script = platform.script.toFilePath();
//      if (fs.path.basename(script) == kSnapshotFileName)
//        return fs.path.dirname(fs.path.dirname(fs.path.dirname(script)));
//      if (fs.path.basename(script) == kFlutterToolsScriptFileName)
//        return fs.path.dirname(fs.path.dirname(fs.path.dirname(fs.path.dirname(script))));
//
//      // If run from a bare script within the repo.
//      if (script.contains('flutter/packages/'))
//        return script.substring(0, script.indexOf('flutter/packages/') + 8);
//      if (script.contains('flutter/examples/'))
//        return script.substring(0, script.indexOf('flutter/examples/') + 8);
//    } catch (error) {
//      // we don't have a logger at the time this is run
//      // (which is why we don't use printTrace here)
//      print(userMessages.runnerNoRoot(error));
//    }
//    return '.';
    return fs.path.join(platform.environment['HOME'], kToolBase );
  }

  @override
  ArgResults parse(Iterable<String> args) {
    try {
      // This is where the CommandRunner would call argParser.parse(args). We
      // override this function so we can call tryArgsCompletion instead, so the
      // completion package can interrogate the argParser, and as part of that,
      // it calls argParser.parse(args) itself and returns the result.
      return tryArgsCompletion(args, argParser);
    } on ArgParserException catch (error) {
      if (error.commands.isEmpty) {
        usageException(error.message);
      }

      Command<void> command = commands[error.commands.first];
      for (String commandName in error.commands.skip(1)) {
        command = command.subcommands[commandName];
      }

      command.usageException(error.message);
      return null;
    }
  }

  @override
  Future<void> run(Iterable<String> args) {
    // Have an invocation of 'build' print out it's sub-commands.
    // TODO(ianh): Move this to the Build command itself somehow.
    if (args.length == 1 && args.first == 'build')
      args = <String>['build', '-h'];

    return super.run(args);
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    final Map<Type, dynamic> contextOverrides = <Type, dynamic>{
      Flags: Flags(topLevelResults),
    };

    // Check for verbose.
    if (topLevelResults['verbose']) {
      // Override the logger.
      contextOverrides[Logger] = VerboseLogger(logger);
    }

    // Don't set wrapColumns unless the user said to: if it's set, then all
    // wrapping will occur at this width explicitly, and won't adapt if the
    // terminal size changes during a run.
    int wrapColumn;
    if (topLevelResults.wasParsed('wrap-column')) {
      try {
        wrapColumn = int.parse(topLevelResults['wrap-column']);
        if (wrapColumn < 0) {
          throwToolExit(userMessages.runnerWrapColumnInvalid(topLevelResults['wrap-column']));
        }
      } on FormatException {
        throwToolExit(userMessages.runnerWrapColumnParseError(topLevelResults['wrap-column']));
      }
    }

    // If we're not writing to a terminal with a defined width, then don't wrap
    // anything, unless the user explicitly said to.
    final bool useWrapping = topLevelResults.wasParsed('wrap')
        ? topLevelResults['wrap']
//        : io.stdio.terminalColumns == null ? false : topLevelResults['wrap'];
        : stdio.terminalColumns == null ? false : topLevelResults['wrap'];
    contextOverrides[OutputPreferences] = OutputPreferences(
      wrapText: useWrapping,
      showColor: topLevelResults['color'],
      wrapColumn: wrapColumn,
    );

//    if (topLevelResults['show-test-device'] ||
//        topLevelResults['device-id'] == FlutterTesterDevices.kTesterDeviceId) {
//      FlutterTesterDevices.showFlutterTesterDevice = true;
//    }

    String recordTo = topLevelResults['record-to'];
    String replayFrom = topLevelResults['replay-from'];

    if (topLevelResults['bug-report']) {
      // --bug-report implies --record-to=<tmp_path>
      final Directory tempDir = const LocalFileSystem()
          .systemTempDirectory
          .createTempSync('flutter_tools_bug_report.');
      recordTo = tempDir.path;

      // Record the arguments that were used to invoke this runner.
      final File manifest = tempDir.childFile('MANIFEST.txt');
      final StringBuffer buffer = StringBuffer()
        ..writeln('# arguments')
        ..writeln(topLevelResults.arguments)
        ..writeln()
        ..writeln('# rest')
        ..writeln(topLevelResults.rest);
      await manifest.writeAsString(buffer.toString(), flush: true);

      // ZIP the recording up once the recording has been serialized.
      addShutdownHook(() async {
        final File zipFile = getUniqueFile(fs.currentDirectory, 'bugreport', 'zip');
        os.zip(tempDir, zipFile);
        printStatus(userMessages.runnerBugReportFinished(zipFile.basename));
      }, ShutdownStage.POST_PROCESS_RECORDING);
      addShutdownHook(() => tempDir.delete(recursive: true), ShutdownStage.CLEANUP);
    }

    assert(recordTo == null || replayFrom == null);

    if (recordTo != null) {
      recordTo = recordTo.trim();
      if (recordTo.isEmpty)
        throwToolExit(userMessages.runnerNoRecordTo);
      contextOverrides.addAll(<Type, dynamic>{
        ProcessManager: getRecordingProcessManager(recordTo),
        FileSystem: getRecordingFileSystem(recordTo),
        Platform: await getRecordingPlatform(recordTo),
      });
//      VMService.enableRecordingConnection(recordTo);
    }

    if (replayFrom != null) {
      replayFrom = replayFrom.trim();
      if (replayFrom.isEmpty)
        throwToolExit(userMessages.runnerNoReplayFrom);
      contextOverrides.addAll(<Type, dynamic>{
        ProcessManager: await getReplayProcessManager(replayFrom),
        FileSystem: getReplayFileSystem(replayFrom),
        Platform: await getReplayPlatform(replayFrom),
      });
//      VMService.enableReplayConnection(replayFrom);
    }

    // We must set Cache.flutterRoot early because other features use it (e.g.
    // enginePath's initializer uses it).
//    final String flutterRoot = topLevelResults['flutter-root'] ?? defaultFlutterRoot;
    final String flutterRoot = defaultFlutterRoot;
    Cache.flutterRoot = fs.path.normalize(fs.path.absolute(flutterRoot));

//    // Set up the tooling configuration.
//    final String enginePath = _findEnginePath(topLevelResults);
//    if (enginePath != null) {
//      contextOverrides.addAll(<Type, dynamic>{
//        Artifacts: Artifacts.getLocalEngine(enginePath, _findEngineBuildPath(topLevelResults, enginePath)),
//      });
//    }

    await context.run<void>(
      overrides: contextOverrides.map<Type, Generator>((Type type, dynamic value) {
        return MapEntry<Type, Generator>(type, () => value);
      }),
      body: () async {
        logger.quiet = topLevelResults['quiet'];

        if (platform.environment['FLUTTER_ALREADY_LOCKED'] != 'true')
          await context.get<Cache>().lock();

        if (topLevelResults['suppress-analytics'])
          sylphUsage.suppressAnalytics = true;

//        _checkFlutterCopy();
        try {
          await FlutterVersion.instance.ensureVersionFile();
        } on FileSystemException catch (e) {
          printError('Failed to write the version file to the artifact cache: "$e".');
          printError('Please ensure you have permissions in the artifact cache directory.');
          throwToolExit('Failed to write the version file');
        }
        if (topLevelResults.command?.name != 'upgrade' && topLevelResults['version-check']) {
          await FlutterVersion.instance.checkFlutterVersionFreshness();
        }

//        if (topLevelResults.wasParsed('packages'))
//          PackageMap.globalPackagesPath = fs.path.normalize(fs.path.absolute(topLevelResults['packages']));
//
//        // See if the user specified a specific device.
//        deviceManager.specifiedDeviceId = topLevelResults['device-id'];

        if (topLevelResults['version']) {
          sylphUsage.sendCommand('version');
          String status;
//          if (topLevelResults['machine']) {
//            status = const JsonEncoder.withIndent('  ').convert(FlutterVersion.instance.toJson());
//          } else {
            status = FlutterVersion.instance.toString();
//          }
          printStatus(status);
          return;
        }

        if (topLevelResults['machine']) {
          throwToolExit('The --machine flag is only valid with the --version flag.', exitCode: 2);
        }
        await super.runCommand(topLevelResults);
      },
    );
  }

//  String _tryEnginePath(String enginePath) {
//    if (fs.isDirectorySync(fs.path.join(enginePath, 'out')))
//      return enginePath;
//    return null;
//  }
//
//  String _findEnginePath(ArgResults globalResults) {
//    String engineSourcePath = globalResults['local-engine-src-path'] ?? platform.environment[kFlutterEngineEnvironmentVariableName];
//
//    if (engineSourcePath == null && globalResults['local-engine'] != null) {
//      try {
//        Uri engineUri = PackageMap(PackageMap.globalPackagesPath).map[kFlutterEnginePackageName];
//        // Skip if sky_engine is the self-contained one.
//        if (engineUri != null && fs.identicalSync(fs.path.join(Cache.flutterRoot, 'bin', 'cache', 'pkg', kFlutterEnginePackageName, 'lib'), engineUri.path)) {
//          engineUri = null;
//        }
//        // If sky_engine is specified and the engineSourcePath not set, try to determine the engineSourcePath by sky_engine setting.
//        // A typical engineUri looks like: file://flutter-engine-local-path/src/out/host_debug_unopt/gen/dart-pkg/sky_engine/lib/
//        if (engineUri?.path != null) {
//          engineSourcePath = fs.directory(engineUri.path)?.parent?.parent?.parent?.parent?.parent?.parent?.path;
//          if (engineSourcePath != null && (engineSourcePath == fs.path.dirname(engineSourcePath) || engineSourcePath.isEmpty)) {
//            engineSourcePath = null;
//            throwToolExit(userMessages.runnerNoEngineSrcDir(kFlutterEnginePackageName, kFlutterEngineEnvironmentVariableName),
//                exitCode: 2);
//          }
//        }
//      } on FileSystemException {
//        engineSourcePath = null;
//      } on FormatException {
//        engineSourcePath = null;
//      }
//      // If engineSourcePath is still not set, try to determine it by flutter root.
//      engineSourcePath ??= _tryEnginePath(fs.path.join(fs.directory(Cache.flutterRoot).parent.path, 'engine', 'src'));
//    }
//
//    if (engineSourcePath != null && _tryEnginePath(engineSourcePath) == null) {
//      throwToolExit(userMessages.runnerNoEngineBuildDirInPath(engineSourcePath),
//          exitCode: 2);
//    }
//
//    return engineSourcePath;
//  }
//
//  String _getHostEngineBasename(String localEngineBasename) {
//    // Determine the host engine directory associated with the local engine:
//    // Strip '_sim_' since there are no host simulator builds.
//    String tmpBasename = localEngineBasename.replaceFirst('_sim_', '_');
//    tmpBasename = tmpBasename.substring(tmpBasename.indexOf('_') + 1);
//    // Strip suffix for various archs.
//    final List<String> suffixes = <String>['_arm', '_arm64', '_x86', '_x64'];
//    for (String suffix in suffixes) {
//      tmpBasename = tmpBasename.replaceFirst(RegExp('$suffix\$'), '');
//    }
//    return 'host_' + tmpBasename;
//  }
//
//  EngineBuildPaths _findEngineBuildPath(ArgResults globalResults, String enginePath) {
//    String localEngine;
//    if (globalResults['local-engine'] != null) {
//      localEngine = globalResults['local-engine'];
//    } else {
//      throwToolExit(userMessages.runnerLocalEngineRequired, exitCode: 2);
//    }
//
//    final String engineBuildPath = fs.path.normalize(fs.path.join(enginePath, 'out', localEngine));
//    if (!fs.isDirectorySync(engineBuildPath)) {
//      throwToolExit(userMessages.runnerNoEngineBuild(engineBuildPath), exitCode: 2);
//    }
//
//    final String basename = fs.path.basename(engineBuildPath);
//    final String hostBasename = _getHostEngineBasename(basename);
//    final String engineHostBuildPath = fs.path.normalize(fs.path.join(fs.path.dirname(engineBuildPath), hostBasename));
//    if (!fs.isDirectorySync(engineHostBuildPath)) {
//      throwToolExit(userMessages.runnerNoEngineBuild(engineHostBuildPath), exitCode: 2);
//    }
//
//    return EngineBuildPaths(targetEngine: engineBuildPath, hostEngine: engineHostBuildPath);
//  }

  static void initFlutterRoot() {
    Cache.flutterRoot ??= defaultFlutterRoot;
  }

//  /// Get the root directories of the repo - the directories containing Dart packages.
//  List<String> getRepoRoots() {
//    final String root = fs.path.absolute(Cache.flutterRoot);
//    // not bin, and not the root
//    return <String>['dev', 'examples', 'packages'].map<String>((String item) {
//      return fs.path.join(root, item);
//    }).toList();
//  }
//
//  /// Get all pub packages in the Flutter repo.
//  List<Directory> getRepoPackages() {
//    return getRepoRoots()
//        .expand<String>((String root) => _gatherProjectPaths(root))
//        .map<Directory>((String dir) => fs.directory(dir))
//        .toList();
//  }
//
//  static List<String> _gatherProjectPaths(String rootPath) {
//    if (fs.isFileSync(fs.path.join(rootPath, '.dartignore')))
//      return <String>[];
//
//
//    final List<String> projectPaths = fs.directory(rootPath)
//        .listSync(followLinks: false)
//        .expand((FileSystemEntity entity) {
//      if (entity is Directory && !fs.path.split(entity.path).contains('.dart_tool')) {
//        return _gatherProjectPaths(entity.path);
//      }
//      return <String>[];
//    })
//        .toList();
//
//    if (fs.isFileSync(fs.path.join(rootPath, 'pubspec.yaml')))
//      projectPaths.add(rootPath);
//
//    return projectPaths;
//  }
//
//  void _checkFlutterCopy() {
//    // If the current directory is contained by a flutter repo, check that it's
//    // the same flutter that is currently running.
//    String directory = fs.path.normalize(fs.path.absolute(fs.currentDirectory.path));
//
//    // Check if the cwd is a flutter dir.
//    while (directory.isNotEmpty) {
//      if (_isDirectoryFlutterRepo(directory)) {
//        if (!_compareResolvedPaths(directory, Cache.flutterRoot)) {
//          printError(userMessages.runnerWrongFlutterInstance(Cache.flutterRoot, directory));
//        }
//
//        break;
//      }
//
//      final String parent = fs.path.dirname(directory);
//      if (parent == directory)
//        break;
//      directory = parent;
//    }
//
//    // Check that the flutter running is that same as the one referenced in the pubspec.
//    if (fs.isFileSync(kPackagesFileName)) {
//      final PackageMap packageMap = PackageMap(kPackagesFileName);
//      Uri flutterUri;
//      try {
//        flutterUri = packageMap.map['flutter'];
//      } on FormatException {
//        // We're not quite sure why this can happen, perhaps the user
//        // accidentally edited the .packages file. Re-running pub should
//        // fix the issue, and we definitely shouldn't crash here.
//        printTrace('Failed to parse .packages file to check flutter dependency.');
//        return;
//      }
//
//      if (flutterUri != null && (flutterUri.scheme == 'file' || flutterUri.scheme == '')) {
//        // .../flutter/packages/flutter/lib
//        final Uri rootUri = flutterUri.resolve('../../..');
//        final String flutterPath = fs.path.normalize(fs.file(rootUri).absolute.path);
//
//        if (!fs.isDirectorySync(flutterPath)) {
//          printError(userMessages.runnerRemovedFlutterRepo(Cache.flutterRoot, flutterPath));
//        } else if (!_compareResolvedPaths(flutterPath, Cache.flutterRoot)) {
//          printError(userMessages.runnerChangedFlutterRepo(Cache.flutterRoot, flutterPath));
//        }
//      }
//    }
  }

//  // Check if `bin/flutter` and `bin/cache/engine.stamp` exist.
//  bool _isDirectoryFlutterRepo(String directory) {
//    return
//      fs.isFileSync(fs.path.join(directory, 'bin/flutter')) &&
//          fs.isFileSync(fs.path.join(directory, 'bin/cache/engine.stamp'));
//  }
//}
//
//bool _compareResolvedPaths(String path1, String path2) {
//  path1 = fs.directory(fs.path.absolute(path1)).resolveSymbolicLinksSync();
//  path2 = fs.directory(fs.path.absolute(path2)).resolveSymbolicLinksSync();
//
//  return path1 == path2;
//}
