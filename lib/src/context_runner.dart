import 'dart:async';

import 'package:process/process.dart';
import 'package:tool_base/tool_base.dart';

import 'base/reporting/reporting.dart';
import 'base/user_messages.dart';
import 'base/concurrent_jobs.dart';

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
//      Config: () => Config(),
      Flags: () => const EmptyFlags(),
      Logger: () => platform.isWindows ? WindowsStdoutLogger() : StdoutLogger(),
      OperatingSystemUtils: () => OperatingSystemUtils(),
      ProcessManager: () => LocalProcessManager(),
      Stdio: () => const Stdio(),
      SystemClock: () => const SystemClock(),
      TimeoutConfiguration: () => const TimeoutConfiguration(),
      Usage: () => Usage(),
      UserMessages: () => UserMessages(),
    },
  );
}
