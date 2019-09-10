import 'dart:async';

import 'package:sylph/src/base/concurrent_jobs.dart';
import 'package:sylph/src/context_runner.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

main() {
  group('concurrent jobs', () {
    group('in context', () {
      testUsingContext('run square', () async {
        final jobArgs = [
          {'n': 10, 'verbose': true},
          {'n': 20, 'verbose': false}
        ];
        List results = await concurrentJobs.runJobs(squareInContext, jobArgs);
        for (int i = 0; i < results.length; i++) {
          expect(results[i], await squareInContext(jobArgs[i]));
        }
      }, overrides: <Type, Generator>{
//        Logger: () => VerboseLogger(StdoutLogger()),
      });

      testUsingContext('run sylph', () async {}, overrides: <Type, Generator>{
//        ConcurrentJobs: () => MockConcurrentJobs,
//        Logger: () => VerboseLogger(StdoutLogger()),
      });
    });

    group('not in context', () {
      test('run square', () async {
        final jobArgs = [
          {'n': 10},
          {'n': 20}
        ];
        List results = await concurrentJobs.runJobs(square, jobArgs);
        for (int i = 0; i < results.length; i++) {
          expect(results[i], await square(jobArgs[i]));
        }
      });
    });
  });
}

// must not be a closure
Future<Map> squareInContext(Map args) async {
  return runInContext<Map>(() async {
    int n = args['n'];
    if (args['verbose']) printTrace('square: n=$n'); //bad example
    return Future.value({'result': n * n});
  });
}

// must not be a closure
Future<Map> square(Map args) {
  int n = args['n'];
  return Future.value({'result': n * n});
}
