import 'package:mockito/mockito.dart';
import 'package:sylph/src/base/reporting/reporting.dart';
import 'package:tool_base/tool_base.dart';

class FakeUsage implements Usage {
  @override
  bool get isFirstRun => false;

  @override
  bool get suppressAnalytics => false;

  @override
  set suppressAnalytics(bool value) { }

  @override
  bool get enabled => true;

  @override
  set enabled(bool value) { }

  @override
  String get clientId => '00000000-0000-4000-0000-000000000000';

  @override
  void sendCommand(String command, { Map<String, String> parameters }) { }

  @override
  void sendEvent(String category, String parameter, { Map<String, String> parameters }) { }

  @override
  void sendTiming(String category, String variableName, Duration duration, { String label }) { }

  @override
  void sendException(dynamic exception) { }

  @override
  Stream<Map<String, dynamic>> get onSend => null;

  @override
  Future<void> ensureAnalyticsSent() => Future<void>.value();

  @override
  void printWelcome() { }
}

class MockClock extends Mock implements SystemClock {}
