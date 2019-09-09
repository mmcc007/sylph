import 'dart:async';
import 'dart:convert';

import 'package:isolate/isolate.dart';
import 'package:sylph/src/config.dart';
import 'package:sylph/src/context_runner.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'sylph_run.dart';

final ConcurrentJobs _kConcurrentJobs = ConcurrentJobs();

/// Currently active implementation of concurrent jobs.
///
/// Override this in tests with a faked/mocked concurrent jobs.
ConcurrentJobs get concurrentJobs =>
    context.get<ConcurrentJobs>() ?? _kConcurrentJobs;

// will work without this signature, but restricted to supported use case
typedef JobFunction = Future<Map> Function(Map args);

class ConcurrentJobs {
  /// Runs any number of jobs concurrently in an isolate for each job.
  /// Number of concurrent jobs is recommended to not exceed number of cores in CPU.
  /// Jobs arguments are passed as a [List] of [Map].
  /// Jobs results are returned as a [List] of [Map] in same order as jobs
  /// argument [List] passed.
// todo: replace load balanced pool with a runner pool.
  Future<List<Map>> runJobs(JobFunction job, List<Map> jobArgs) {
    return LoadBalancer.create(jobArgs.length, IsolateRunner.spawn)
        .then((LoadBalancer pool) {
      var jobResults = List<Future<Map>>(jobArgs.length);
      for (int i = 0; i < jobArgs.length; i++) {
        jobResults[i] = pool.run<Map, Map>(job, jobArgs[i]);
      }
      // Wait for all jobs to complete.
      return Future.wait(jobResults).whenComplete(pool.close);
    });
  }
}

/// Runs [runSylphJob] in an isolate.
/// Function signature must match [JobFunction].
Future<Map> runSylphJobInIsolate(Map args) async {
  // unpack args
  final testSuite = jsonDecode(args['test_suite']);
  final config = jsonDecode(args['config']);
  final poolName = args['pool_name'];
  final projectArn = args['projectArn'];
  final sylphRunName = args['sylph_run_name'];
  final sylphRunTimeout = args['sylph_run_timeout'];
  final jobVerbose = args['jobVerbose'];

  // run runSylphTests
  bool succeeded;
  if (jobVerbose) {
    succeeded = await runInContext<bool>(() {
      return runSylphJob(testSuite, config, poolName, projectArn, sylphRunName,
          sylphRunTimeout);
    }, overrides: <Type, Generator>{
      Logger: () => VerboseLogger(
          platform.isWindows ? WindowsStdoutLogger() : StdoutLogger()),
    });
  } else {
    succeeded = await runInContext<bool>(() {
      return runSylphJob(testSuite, config, poolName, projectArn, sylphRunName,
          sylphRunTimeout);
    });
  }

  return {'result': succeeded};
}

/// Pack [runSylphJob] args into [Map].
Map<String, dynamic> packArgs(
    TestSuite testSuite,
    Config config,
    poolName,
    String projectArn,
    String sylphRunName,
    int sylphRunTimeout,
    bool jobVerbose) {
  return {
    'test_suite': jsonEncode(testSuite),
    'config': jsonEncode(config),
    'pool_name': poolName,
    'projectArn': projectArn,
    'sylph_run_name': sylphRunName,
    'sylph_run_timeout': sylphRunTimeout,
    'jobVerbose': jobVerbose,
  };
}
