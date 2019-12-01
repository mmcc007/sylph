import 'package:mockito/mockito.dart';
import 'package:sylph/src/base/version.dart';

class MockFlutterVersion extends Mock implements FlutterVersion {
  MockFlutterVersion({bool isStable = false}) : _isStable = isStable;

  final bool _isStable;

  @override
  bool get isMaster => !_isStable;
}