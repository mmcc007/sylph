import 'dart:async';

import 'package:isolate/isolate.dart';

// will work without this signature, but restricted to supported use case
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
