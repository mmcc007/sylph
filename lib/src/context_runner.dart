import 'dart:async';

import 'package:process/process.dart';
import 'package:reporting/reporting.dart';
import 'package:tool_base/tool_base.dart';

import '../runner.dart';
import 'base/concurrent_jobs.dart';
import 'device_farm.dart';

Future<T> runInContext<T>(
  FutureOr<T> runner(), {
  Map<Type, Generator> overrides,
}) async {
  return await context.run<T>(
    name: 'global fallbacks',
    body: runner,
    overrides: overrides,
    fallbacks: <Type, Generator>{
      BotDetector: () => const BotDetector(),
      ConcurrentJobs: () => ConcurrentJobs(),
      Config: () => Config(configFile),
      DeviceFarm:()=>DeviceFarm(),
      Flags: () => const EmptyFlags(),
      Logger: () => platform.isWindows ? WindowsStdoutLogger() : StdoutLogger(),
      OperatingSystemUtils: () => OperatingSystemUtils(),
      ProcessManager: () => LocalProcessManager(),
      Stdio: () => const Stdio(),
      SystemClock: () => const SystemClock(),
      TimeoutConfiguration: () => const TimeoutConfiguration(),
      Usage: () => Usage(kAnalyticsUA, kSettings),
//      UserMessages: () => UserMessages(),
    },
  );
}
