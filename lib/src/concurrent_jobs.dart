import 'dart:async';
import 'dart:convert';

import 'package:isolate/isolate.dart';

import 'sylph_run.dart';

typedef JobFunction = Future<Map> Function(Map args);

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

/// Runs [runSylphJob] in an isolate.
/// Method signature should match [JobFunction].
Future<Map> runSylphJobInIsolate(Map args) async {
  // unpack args
  final testSuite = jsonDecode(args['test_suite']);
  final config = jsonDecode(args['config']);
  final poolName = args['pool_name'];
  final projectArn = args['projectArn'];
  final sylphRunName = args['sylph_run_name'];
  final sylphRunTimeout = args['sylph_run_timeout'];

  // run runSylphTests
  final succeeded = await runSylphJob(
      testSuite, config, poolName, projectArn, sylphRunName, sylphRunTimeout);

  return {'result': succeeded};
}

/// Pack [runSylphJob] args into [Map].
Map<String, dynamic> packArgs(Map testSuite, Map config, poolName, String projectArn,
    String sylphRunName, int sylphRunTimeout) {
  return {
    'test_suite': jsonEncode(testSuite),
    'config': jsonEncode(config),
    'pool_name': poolName,
    'projectArn': projectArn,
    'sylph_run_name': sylphRunName,
    'sylph_run_timeout': sylphRunTimeout,
  };
}
