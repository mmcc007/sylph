import 'dart:async';

import 'package:sylph/src/concurrent_jobs.dart';
import 'package:sylph/src/context_runner.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'src/context.dart';

main() {
  group('concurrent jobs', () {
    testUsingContext('square', () async {
      final jobArgs = [
        {'n': 10, 'verbose': true},
        {'n': 20, 'verbose': false}
      ];
      List results = await ConcurrentJobs().runJobs(squareFuture, jobArgs);
      for (int i = 0; i < results.length; i++) {
//        print("squareFuture job #$i: job(${jobArgs[i]}) = ${results[i]}");
        expect(results[i], await squareFuture(jobArgs[i]));
      }
    }, overrides: <Type, Generator>{
      Logger: () => VerboseLogger(StdoutLogger()),
    });
  });
}

Future<Map> squareFuture(Map args) async {
  return runInContext<Map>(() async {
    int n = args['n'];
    printStatus('square: n=$n');
    if (args['verbose']) printTrace('running square');
    return Future.value({'result': n * n});
  });
}
