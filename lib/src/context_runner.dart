import 'dart:async';

import 'package:process/process.dart';
import 'package:sylph/src/concurrent_jobs.dart';
import 'package:tool_base/tool_base.dart';

Future<T> runInContext<T>(
  FutureOr<T> runner(), {
  Map<Type, Generator> overrides,
}) async {
  return await context.run<T>(
    name: 'global fallbacks',
    body: runner,
    overrides: overrides,
    fallbacks: <Type, Generator>{
//      AndroidSdk: AndroidSdk.locateAndroidSdk,
      BotDetector: () => const BotDetector(),
      ConcurrentJobs: () => ConcurrentJobs(),
      Config: () => Config(),
      Logger: () => platform.isWindows ? WindowsStdoutLogger() : StdoutLogger(),
      OperatingSystemUtils: () => OperatingSystemUtils(),
      ProcessManager: () => LocalProcessManager(),
      Stdio: () => const Stdio(),
      TimeoutConfiguration: () => const TimeoutConfiguration(),
    },
  );
}
