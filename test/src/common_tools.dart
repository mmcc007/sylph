import 'package:args/command_runner.dart';
import 'package:sylph/src/base/runner/sylph_command.dart';
import 'package:sylph/src/base/runner/sylph_command_runner.dart';

CommandRunner<void> createTestCommandRunner([SylphCommand command]) {
  final SylphCommandRunner runner = SylphCommandRunner();
  if (command != null) runner.addCommand(command);
  return runner;
}
